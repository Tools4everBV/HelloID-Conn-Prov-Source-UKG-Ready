## API Documentation 
## https://secure4.saashr.com/ta/docs/rest/public/#

#region Initialize default properties
$InformationPreference = 'Continue'
$ErrorActionPreference = 'Stop'

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
                 Write-Error (($reader.ReadToEnd() | ConvertFrom-Json) | ConvertTo-Json) -InformationAction Continue
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
                                Write-Information "Rate Limit - Retrying in $($retrySeconds) seconds [$($uri)]"
                                Start-Sleep $retrySeconds
                                $retrySeconds = $retrySeconds*2
                            } 
                            else {
                                Write-Error ($response | ConvertTo-Json)
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
    Write-Information "Retrieving Cost Centers for Departments"
    $costCenters = (Get-Request -Config $config -Endpoint "/v2/companies/$($config.CompanyId)/config/cost-centers?tree_index=0").cost_centers

    #region Departments
    Write-Information "Processing Departments"
    foreach($item in $costCenters)
    {
        $row = @{
                ExternalId = $item.id
                DisplayName = $item.Name
                Name = $item.external_id
                ManagerExternalId = $null
                ParentExternalId	= $item.parent_id
        }
    
        $row | ConvertTo-Json -Depth 10
    }
    Write-Information "Finished Processing Departments"
    #endregion Departments


#endregion Execute
