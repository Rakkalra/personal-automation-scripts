# Personal automation scripts

Sanitized, parameterized adaptations of earlier PowerShell scripts. No organization credentials, addresses, hostnames, device inventories, or Azure identifiers are included.

| Script | Purpose |
| --- | --- |
| `Stop-IdleAzureVm.ps1` | Check Windows VM CPU and user sessions before deallocation; dry run by default. |
| `New-PrtgGroups.ps1` | Create multiple PRTG groups below a supplied parent group. Supports `-WhatIf`. |
| `New-PrtgDevices.ps1` | Bulk-create devices from a private Name/Host CSV; supports `-WhatIf`. |
| `Export-PrtgInventory.ps1` | Export groups and devices with hierarchy paths to local private CSVs. |
| `Get-PrtgGroup.ps1` | Query a PRTG group using the experimental v2 API. |

## PRTG

Requires PowerShell 7.2+, HTTPS with a trusted certificate, API access, and a locally supplied `PRTG_API_KEY` environment variable. The experimental API is version-dependent. These adaptations have not been executed against a live PRTG server.

```powershell
./Get-PrtgGroup.ps1 -Server https://monitor.example.com -GroupId 100
./New-PrtgGroups.ps1 -Server https://monitor.example.com -ParentGroupId 100 -GroupNames 'Lab Apps','Lab Databases' -WhatIf
```

Group IDs and server addresses above are examples. Supply your own locally. Never commit secrets or exported monitoring inventory.

## Azure

Requires Az.Accounts, Az.Compute, Az.Monitor, and an Azure Automation managed identity with permissions to read VM metrics, execute guest Run Command, and deallocate the target VM. Scope permissions to your intended resources.

```powershell
./Stop-IdleAzureVm.ps1 -SubscriptionId '<your-subscription-id>' -ResourceGroupName '<your-resource-group>' -VMName '<your-vm>'
```

The script defaults to a 5% CPU threshold across 60 minutes and performs a dry run. Add `-Apply` only after testing. Missing metrics, unknown guest results, and localized `quser` no-session responses cause shutdown to be skipped. Low CPU and no interactive users do not establish that background workloads are idle; use this only for appropriate lab VMs.

The earlier personal lab used a different threshold. This published adaptation adds fail-closed checks and does not preserve private deployment settings. No live cloud actions were used to validate it.

## Additional PRTG scripts

`New-PrtgDevices.ps1` uses the recovered experimental device creation endpoint with a Name/Host CSV. It validates duplicate names inside the CSV but does not check existing server devices. Preview with `-WhatIf`; repeated applies can create duplicates.

`Export-PrtgInventory.ps1` reconstructs the earlier classic XML table export logic. Supply `PRTG_USERNAME` and `PRTG_PASSHASH` as local environment variables. It writes PRTG_All_Groups.csv and PRTG_Full_Inventory.csv under private-inventory. It retains trusted HTTPS validation. A passhash is a secret; protect it and server/proxy query logs. Check output counts against your console before relying on the export.

These are adaptations/reconstructions from recovered API details, not byte-for-byte original scripts. No live PRTG or Azure execution has been performed, and PowerShell parser validation was unavailable in the preparation environment.
