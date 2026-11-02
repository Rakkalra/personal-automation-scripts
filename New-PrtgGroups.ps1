#requires -Version 7.2
<# Sanitized adaptation of the earlier PRTG bulk group creation script.
Uses the experimental API v2; verify support on your installed PRTG version.
Set PRTG_API_KEY in your local environment. Never commit API keys.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][uri]$Server,
    [Parameter(Mandatory)][ValidateRange(1,2147483647)][int]$ParentGroupId,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string[]]$GroupNames
)
$ErrorActionPreference = 'Stop'
if ($Server.Scheme -ne 'https') { throw 'Use an HTTPS server URL.' }
if (-not $env:PRTG_API_KEY) { throw 'Set PRTG_API_KEY in your local environment.' }
$headers = @{ Authorization = "Bearer $env:PRTG_API_KEY"; Accept = 'application/json' }
$endpoint = "$($Server.AbsoluteUri.TrimEnd('/'))/api/v2/experimental/groups/$ParentGroupId/group"
foreach ($name in $GroupNames) {
    if ([string]::IsNullOrWhiteSpace($name)) { throw 'Group names must not be blank.' }
    if ($PSCmdlet.ShouldProcess("Parent group $ParentGroupId", "Create group $name")) {
        $body = @{ basic = @{ name = $name } } | ConvertTo-Json -Depth 4 -Compress
        Invoke-RestMethod -Uri $endpoint -Method Post -Headers $headers -ContentType 'application/json' -Body $body
    }
}
