#requires -Version 7.2
# Sanitized adaptation of earlier bulk device onboarding API logic.
# CSV input must have Name and Host columns. Keep real CSV inventory private.
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][uri]$Server,
    [Parameter(Mandatory)][ValidateRange(1,2147483647)][int]$GroupId,
    [Parameter(Mandatory)][string]$CsvPath
)
$ErrorActionPreference = 'Stop'
if ($Server.Scheme -ne 'https') { throw 'Use HTTPS.' }
if (-not $env:PRTG_API_KEY) { throw 'Set PRTG_API_KEY locally.' }
$headers = @{ Authorization = "Bearer $env:PRTG_API_KEY"; Accept = 'application/json' }
$endpoint = "$($Server.AbsoluteUri.TrimEnd('/'))/api/v2/experimental/groups/$GroupId/device"
$devices = @(Import-Csv -LiteralPath $CsvPath)
$seen = @{}
foreach ($device in $devices) {
    if ([string]::IsNullOrWhiteSpace($device.Name) -or [string]::IsNullOrWhiteSpace($device.Host)) { throw 'Every CSV row needs Name and Host.' }
    if ($seen.ContainsKey($device.Name)) { throw 'Duplicate device name in CSV.' }
    $seen[$device.Name] = $true
}
foreach ($device in $devices) {
    if ($PSCmdlet.ShouldProcess("Group $GroupId", "Create device $($device.Name)")) {
        $body = @{ basic = @{ name = $device.Name; host = $device.Host } } | ConvertTo-Json -Depth 4 -Compress
        Invoke-RestMethod -Uri $endpoint -Method Post -Headers $headers -ContentType 'application/json' -Body $body
    }
}
# Existing server inventory is not checked. Review it before applying to avoid duplicates.
