# HelloID-Conn-Prov-Source-UKG-Ready
UKG Ready (Formerly Kronos Workforce Ready)

| :information_source: Information |
|:---------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.       |

<br />

<p align="center">
  ![image](https://user-images.githubusercontent.com/24281600/188179608-ffd99c49-da3e-4743-a23f-5d181fe7ac46.png)
</p>

<!-- TABLE OF CONTENTS -->
## Table of Contents
* [Getting Started](#getting-started)
* [Requirements](#Requirements)
* [Setup the PowerShell connector](#setup-the-powershell-connector)
* [Sample VPN Scripts](#sample-vpn-scripts)

<!-- GETTING STARTED -->
## Getting Started
By using this connector you will have the ability to import data into HelloID:
* Employee Demographics
* Employee Details
* Employee Pay Info
* Employee Contacts
* Employee Custom Fields
* Cost Centers

## Requirements
See https://secure4.saashr.com/ta/docs/rest/public/
- Authentication is done using your Account username, password and Api-Key header. Once authenticated the API will issue a bearer token with a TTL of 1 hour.
- Api-Key header requires generated api key as value. The value can be generated on Api Keys control in Company Setup (client level)/ Company Configuration (admin level).



## Setup the PowerShell connector
1. Add a new 'Source System' to HelloID and make sure to import all the necessary files.

    - [ ] configuration.json
    - [ ] persons.ps1
    - [ ] departments.ps1


2. Fill in the required fields on the 'Configuration' tab.

# HelloID Docs
The official HelloID documentation can be found at: https://docs.helloid.com/
