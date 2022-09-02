# API Documentation 
## https://secure4.saashr.com/ta/docs/rest/public/#

#region Initialize default properties
#$InformationPreference = 'Continue'
#$ErrorActionPreference = 'Stop'

$config = ConvertFrom-Json $configuration
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 
#endregion Initialize default properties

#region Support Functions
function Get-AccessToken {
    [cmdletbinding()]
    Param (
        [string]$BaseURI,
        [string]$Username,
        [string]$Password,
        [string]$Company,
        [string]$Token
    )
    Process {
        $auth_headers = @{ 
            "Api-Key" = $Token 
            "Accept" = "application/json"
            "Content-Type" = "application/json"
        }
        $body = @{
                "credentials"= @{
                    "username" = $Username
                    "password" = $Password
                    "company" = $Company
                }
        }
          
        if($Global:AccessToken.Token.length -lt 1 -or $Global:AccessToken.Expires -lt (Get-Date))
        {
            $uri = "$($BaseURI)/v1/login"
            #Write-Information "POST $uri"
            try {
                $result = Invoke-RestMethod -Method POST -Headers $auth_headers -Uri $uri -Body ($body | ConvertTo-Json)
                $Global:AccessToken = @{ Token = $result.token; Expires = (Get-Date).AddMilliseconds($result.ttl*0.9) }
            } catch {
                 $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                 $reader.BaseStream.Position = 0
                 $reader.DiscardBufferedData()
                 Throw (($reader.ReadToEnd() | ConvertFrom-Json) | ConvertTo-Json)
            }
        }
        
    }
}

function Get-Request() {
[cmdletbinding()]
    Param (
        [object]$Config,
        [string]$Endpoint,
        [object]$Body
    )
    Process {
                Get-AccessToken `
                            -BaseURI $config.BaseURI `
                            -Username $config.Username `
                            -Password $config.Password `
                            -Company $config.Company `
                            -Token $config.Token

                $auth_headers = @{ 
                        "Authentication"= "Bearer $($Global:AccessToken.token)"
                        "Api-Key" = $config.Token
                        "Accept" = "application/json"
                        "Content-Type" = "application/json"
                    }
                             
                $uri = "$($config.BaseURI)$($Endpoint)"
                #Write-Information "GET $uri"
                $retryCount = 0;
                $retrySeconds = 2;
                while($true) {
                    try {
                        $result = Invoke-RestMethod -Method GET -Headers $auth_headers -Uri $uri -Body $Body
                        @($result)
                        break
                    } catch {
                        if($_.Exception.Response.StatusCode.value__ -eq 401) {
                            Get-AccessToken `
                            -BaseURI $config.BaseURI `
                            -Username $config.Username `
                            -Password $config.Password `
                            -Company $config.Company `
                            -Token $config.Token
                        }
                        else {
                            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                            $reader.BaseStream.Position = 0
                            $reader.DiscardBufferedData()
                            $response = ($reader.ReadToEnd() | ConvertFrom-Json)
                                
                            if($response.errors[0].code -eq 100 -and $retryCount -lt 5) {
                                $retryCount++;
                                #Write-Information "Rate Limit - Retrying in $($retrySeconds) seconds [$($uri)]"
                                Start-Sleep $retrySeconds
                                $retrySeconds = $retrySeconds*2
                            } 
                            else {
                                Throw ($response | ConvertTo-Json)
                                break
                            }    
                        }
                    }
                }
    }
}

function Get-ObjectProperties {
    param ($Object, $Depth = 0, $MaxDepth = 10)
    $OutObject = @{};

    foreach($prop in $Object.PSObject.properties)
    {
        if ($prop.TypeNameOfValue -eq "System.Management.Automation.PSCustomObject" -or $prop.TypeNameOfValue -eq "System.Object" -and $Depth -lt $MaxDepth)
        {
            $OutObject[$prop.Name] = Get-ObjectProperties -Object $prop.Value -Depth ($Depth + 1);
        }
        elseif ($prop.TypeNameOfValue -eq "System.Object[]") 
        {
            $OutObject[$prop.Name] = [System.Collections.ArrayList]@()
            foreach($item in $prop.Value)
            {
                $OutObject[$prop.Name].Add($item)
            }
        }
        else
        {
            $OutObject[$prop.Name] = "$($prop.Value)"
        }
    }
    return $OutObject;
}

#endregion Support Functions

#region Execute
    Write-Information "Retrieving Employees"
    $employees = (Get-Request -Config $config -Endpoint "/v2/companies/$($config.CompanyId)/employees").employees
    
    Write-Information "Retrieving Jobs"
    $jobs = (Get-Request -Config $config -Endpoint "/v2/companies/$($config.CompanyId)/lookup/jobs").items | Group-Object id -AsHashTable

    Write-Information "Retrieving Cost Centers"
    $costCenters = (Get-Request -Config $config -Endpoint "/v2/companies/$($config.CompanyId)/config/cost-centers?tree_index=0").cost_centers | Group-Object id -AsHashTable
    
    Write-Information "Retrieving Cost Center Jobs"
    $costCenterJobs = (Get-Request -Config $config -Endpoint "/v2/companies/$($config.CompanyId)/config/cost-center-jobs").costCenterJobs | Group-Object id -AsHashTable

    Write-Information "Retrieving Pay Types"
    $payTypes = (Get-Request -Config $config  -Endpoint "/v1/company/pay-types").pay_types | Group-Object id -AsHashTable

    $payInfo = @{};
    $detail = @{};
    $customFields = @{};
    $contacts = @{};

    Write-Information "Retrieving Pay Info"
    foreach($emp in [Linq.Enumerable]::Distinct([string[]]$employees.id)) {
        $payInfo["$($emp)"] = Get-Request -Config $config -Endpoint "/v2/companies/67117690/employees/$($emp)/pay-info"
        $detail["$($emp)"] = (Get-Request -Config $config -Endpoint "/v2/companies/67117690/employees/$($emp)")
        #Additional Data
        #$customFields["$($emp)"] = (Get-Request -Config $config -Endpoint "/v2/companies/67117690/employees/$($emp)/hr-custom-fields").hr_custom_fields
        #$contacts["$($emp)"] = (Get-Request -Config $config -Endpoint "/v2/companies/67117690/employees/$($emp)/contacts").contacts
    }
#region Persons
Write-Information "Processing Persons"
foreach($row in $employees)
{
    $person = @{}
    $person = Get-ObjectProperties -Object $row

    $person["ExternalId"] = $row.id
    $person["DisplayName"] = "$($row.first_name) $($row.last_name) ($($person["ExternalId"]))"
    $person["Role"] = "Employee"
    $person["Details"] = $detail["$($($row.id))"]

    $person['Contracts'] = [System.Collections.ArrayList]@();
    $contract = @{}
    try { $contract = Get-ObjectProperties -Object $payInfo["$($row.id)"] } catch{}
    $contract["ExternalId"] = $person["ExternalId"];
    try { $contract["CostCenterJob"] = $costCenterJobs[$payInfo["$($row.id)"].default_job.id][0] } catch{}
    try { $contract["PayType"] = $payTypes[$payInfo["$($row.id)"].pay_type.id][0]  } catch{}
    try { $contract["Job"] = $jobs[$payInfo["$($row.id)"].default_job.id][0]  } catch{}
    
    $contract['started'] = $row.dates.started;
    $contract['terminated'] = $row.dates.terminated
    $contract['re_hired'] = $row.dates.re_hired
    $contract['hired'] = $row.dates.hired

    [void]$person['Contracts'].Add($contract)
    
    Write-Output $person | ConvertTo-Json -Depth 10;
}
Write-Information "Finished Processing Persons"
#endregion Persons


#endregion Execute
