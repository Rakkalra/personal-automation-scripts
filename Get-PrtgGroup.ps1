#requires -Version 7.2
# Sanitized adaptation of the earlier PRTG experimental API group query.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][uri]$Server,
    [Parameter(Mandatory)][ValidateRange(1,2147483647)][int]$GroupId
)
$ErrorActionPreference = 'Stop'
if ($Server.Scheme -ne 'https') { throw 'Use an HTTPS server URL.' }
if (-not $env:PRTG_API_KEY) { throw 'Set PRTG_API_KEY in your local environment.' }
$headers = @{ Authorization = "Bearer $env:PRTG_API_KEY"; Accept = 'application/json' }
$endpoint = "$($Server.AbsoluteUri.TrimEnd('/'))/api/v2/experimental/groups/$GroupId"
Invoke-RestMethod -Uri $endpoint -Headers $headers -Method Get
