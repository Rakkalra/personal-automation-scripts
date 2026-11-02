#requires -Version 7.2
# Sanitized reconstruction of earlier classic PRTG group/device table exports.
# CSVs contain private inventory. Do not commit generated output.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][uri]$Server,
    [string]$OutputDirectory = './private-inventory'
)
$ErrorActionPreference = 'Stop'
if ($Server.Scheme -ne 'https') { throw 'Use HTTPS.' }
if (-not $env:PRTG_USERNAME -or -not $env:PRTG_PASSHASH) { throw 'Set PRTG_USERNAME and PRTG_PASSHASH locally.' }
$root = $Server.AbsoluteUri.TrimEnd('/')
$auth = 'username=' + [uri]::EscapeDataString($env:PRTG_USERNAME) + '&passhash=' + [uri]::EscapeDataString($env:PRTG_PASSHASH)
function Get-TableItems([string]$Content, [string]$Columns) {
    $uri = "$root/api/table.xml?content=$Content&columns=$Columns&count=*&$auth"
    try { [xml]$table = Invoke-RestMethod -Uri $uri -Method Get }
    catch { throw "PRTG $Content request failed. Check connectivity and permissions locally." }
    if ($table.SelectSingleNode('//error')) { throw 'PRTG returned an API error.' }
    @($table.SelectNodes('//item'))
}
$groups = @(Get-TableItems 'groups' 'objid,name,parentid,probe')
$devices = @(Get-TableItems 'devices' 'objid,device,host,group,probe,parentid')
$index = @{}
foreach ($g in $groups) { $index[[string]$g.objid] = $g }
function Get-GroupPath([string]$Id) {
    $names = [System.Collections.Generic.List[string]]::new()
    $seen = @{}
    while ($index.ContainsKey($Id)) {
        if ($seen.ContainsKey($Id)) { throw 'Cycle detected in group hierarchy.' }
        $seen[$Id] = $true
        $g = $index[$Id]
        $names.Insert(0,[string]$g.name)
        $Id = [string]$g.parentid
    }
    $names -join ' / '
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$groups | ForEach-Object {
    [pscustomobject]@{ GroupId=[string]$_.objid; Name=[string]$_.name; ParentId=[string]$_.parentid; Probe=[string]$_.probe; FullGroupPath=(Get-GroupPath ([string]$_.objid)) }
} | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'PRTG_All_Groups.csv') -NoTypeInformation
$devices | ForEach-Object {
    [pscustomobject]@{ DeviceObjectID=[string]$_.objid; DeviceName=[string]$_.device; HostOrIP=[string]$_.host; ImmediateGroup=[string]$_.group; Probe=[string]$_.probe; ParentObjectID=[string]$_.parentid; FullGroupPath=(Get-GroupPath ([string]$_.parentid)) }
} | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'PRTG_Full_Inventory.csv') -NoTypeInformation
# Classic passhash authentication is sent in the HTTPS query; protect proxy/server logs.
