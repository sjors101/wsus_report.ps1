## wsus_report.ps1
Gathers the node status based on a computergroup, and outputs into html format + nagios check

## Instructions:
* Match the ComputerGroup with the computergroup name you configured in the WSUS GUI.
* Make sure the application can write the output file to the requested location.

## Example:
Run without Nagios output
```sh
.\wsus_report.ps1 -ComputerGroup 'Production' -OutputFile 'C:\output.html'
```
Run with Nagios output
```sh
.\wsus_report.ps1 -ComputerGroup 'Production' -OutputFile 'C:\output.html' -Nagios True
```

## NRPE config:
Add these lines to NRPE:

```sh
; POWERSHELL WRAPPING -
ps1 = cmd /c echo scripts\\%SCRIPT% %ARGS%; exit($lastexitcode) | powershell.exe -command -

[/settings/external scripts/wrapped scripts]
wsus_report = wsus_report.ps1 $ARG1$ $ARG2$ $ARG3$
```
