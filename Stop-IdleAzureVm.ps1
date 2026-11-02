#requires -Version 7.2
#requires -Modules Az.Accounts, Az.Compute, Az.Monitor
<# Sanitized adaptation of a personal Azure Automation lab runbook.
Safety changes: dry run by default; require an explicit no-session marker;
fail closed on guest query errors. Windows VMs only. No live validation.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$SubscriptionId,
    [Parameter(Mandatory)][string]$ResourceGroupName,
    [Parameter(Mandatory)][string]$VMName,
    [ValidateRange(1,100)][double]$CpuThreshold = 5,
    [ValidateRange(15,1440)][int]$LookbackMinutes = 60,
    [switch]$Apply
)
$ErrorActionPreference = 'Stop'
Disable-AzContextAutosave -Scope Process | Out-Null
Connect-AzAccount -Identity | Out-Null
Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
$vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
if ($vm.StorageProfile.OsDisk.OsType -ne 'Windows') { throw 'Only Windows VMs are supported.' }
$end = Get-Date
$metric = Get-AzMetric -ResourceId $vm.Id -MetricName 'Percentage CPU' -StartTime $end.AddMinutes(-$LookbackMinutes) -EndTime $end -TimeGrain ([timespan]::FromMinutes(5)) -AggregationType Average
$samples = @($metric.Data | Where-Object { $null -ne $_.Average } | Select-Object -ExpandProperty Average)
if ($samples.Count -lt [math]::Ceiling($LookbackMinutes / 5 * 0.8)) { throw 'Insufficient CPU metric coverage; skipping shutdown.' }
$average = ($samples | Measure-Object -Average).Average
Write-Output "Average CPU: $average percent"
if ($average -ge $CpuThreshold) { Write-Output 'CPU is not below threshold; skipping.'; return }
$guestScript = @'
$ErrorActionPreference = 'Stop'
try {
    $quser = Join-Path $env:SystemRoot 'System32\quser.exe'
    if (-not (Test-Path $quser)) { throw 'quser unavailable' }
    $result = & $quser 2>&1
    $code = $LASTEXITCODE
    $text = $result | Out-String
    if ($code -eq 0 -and $text.Trim()) { 'IDLE_CHECK_USERS_PRESENT' }
    elseif ($code -eq 1 -and $text -match 'No User exists') { 'IDLE_CHECK_NO_SESSIONS' }
    else { 'IDLE_CHECK_UNKNOWN' }
} catch { 'IDLE_CHECK_UNKNOWN' }
'@
$result = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName -CommandId 'RunPowerShellScript' -ScriptString $guestScript
$output = ($result.Value | ForEach-Object { $_.Message }) -join "`n"
if ($output -notmatch '(?m)^IDLE_CHECK_NO_SESSIONS\r?$' -or $output -match 'IDLE_CHECK_(USERS_PRESENT|UNKNOWN)') {
    Write-Output 'Users present or session state unknown; skipping shutdown.'; return
}
if (-not $Apply) { Write-Output 'Dry run: VM qualifies for deallocation. Use -Apply to enable.'; return }
if ($PSCmdlet.ShouldProcess($VMName, 'Stop and deallocate Azure VM')) {
    Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Force
}
