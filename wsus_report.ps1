# Author: Sjors101 <https://github.com/sjors101/>, 17/08/2017
# Gathers the node status based on a computergroup, and outputs into html format + nagios check
#
# * Match the ComputerGroup with the computergroup name you configured in the WSUS GUI.
# * Make sure the application can write the output file to the requested location.
#
# EXAMPLE: .\wsus_report.ps1 -ComputerGroup 'Production' -OutputFile 'C:\output.html'
# EXAMPLE with Nagios: .\wsus_report.ps1 -ComputerGroup 'Production' -OutputFile 'C:\output.html' -Nagios True
#################################################################################################

# Check input
Param ( [string]$ComputerGroup, [string]$OutputFile, [string]$Nagios )

IF([string]::IsNullOrWhiteSpace($ComputerGroup)) {            
    Write-Host "WARN: Missing ComputerGroup.`n`n EXAMPLE: .\wsus_report.ps1 -ComputerGroup 'Production' -OutputFile 'C:\output.html'"
    exit 2
}
IF([string]::IsNullOrWhiteSpace($OutputFile)) {            
    Write-Host "WARN: Missing OutputFile. `n`n EXAMPLE: .\wsus_report.ps1 -ComputerGroup 'Production' -OutputFile 'C:\output.html'"
    exit 2
}
IF(![string]::IsNullOrWhiteSpace($Nagios)) {            
    $Nagios = $True     
}

function wsuscompgroups($WsusComputerGroup){

    #Load assemblies
    [void][system.reflection.assembly]::LoadWithPartialName('Microsoft.UpdateServices.Administration')
    $Global:wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer('wsus01',$False, 8530)
    $computerscope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope
    $updatescope = New-Object Microsoft.UpdateServices.Administration.UpdateScope

    #Gather only servers from comp group
    $group = $wsus.GetComputerTargetGroups() | foreach {
        if ($_.Name -eq $WsusComputerGroup){
            $_.Id
        }
    } 
    $ServersId = @($wsus.GetComputerTargets($computerscope) | Where {
       $_.ComputerTargetGroupIds -eq $group
    })
   
    ForEach ($s in $ServersId) {
        $objSummary = $s.GetUpdateInstallationSummary()
               
        if ($s.LastSyncResult -eq "Succeeded" -and $objSummary.InstalledPendingRebootCount+$objSummary.FailedCount+$objSummary.UnknownCount+$objSummary.NotInstalledCount -eq "0"){
            #### All good ####
            $CurrentStatus = "True"
        }
        else{
            #### This host needs attention ####
            $CurrentStatus = "False"
        }       
        
        $dict = @{
            "CurrentStatus" = $CurrentStatus
            "FQDN" = $s.FullDomainName
            "OS" =$s.OSDescription
            "Lastupdate"=$objSummary.LastUpdated
            "Result"=$s.LastSyncResult
            "Installed"=$objSummary.InstalledCount
            "NotApplicableCount"=$objSummary.NotApplicableCount
            "Notinstalled"=$objSummary.NotInstalledCount
            "Pendingreboot"=$objSummary.InstalledPendingRebootCount
            "Failed"=$objSummary.FailedCount
            "Unknown"=$objSummary.UnknownCount
        }

        [array]$log = $log+ $dict
    }
    return $log
}

$Msghead = "<?php header('HTTP/1.0 200 OK'); ?>"

$MsgBody = $MsgBody + "<table border=""1"" cellspacing=""2"" cellpadding=""4"" style=""font-family:Calibri, Candara, Segoe, 'Segoe UI', Optima, Arial, sans-serif"">"
$MsgBody = $MsgBody + "<tr>"
$MsgBody = $MsgBody + "<th>FQDN</th>"
$MsgBody = $MsgBody + "<th>OS</th>"
$MsgBody = $MsgBody + "<th>Lastupdate</th>"
$MsgBody = $MsgBody + "<th>Result</th>"
$MsgBody = $MsgBody + "<th>Installed</th>"
$MsgBody = $MsgBody + "<th>NotApplicable</th>"
$MsgBody = $MsgBody + "<th>Not installed</th>"
$MsgBody = $MsgBody + "<th>Pending reboot</th>"
$MsgBody = $MsgBody + "<th>Failed</th>"
$MsgBody = $MsgBody + "<th>Unknown</th>"
$MsgBody = $MsgBody + "</tr>"

ForEach ($s in wsuscompgroups($ComputerGroup)){
    if ($s.CurrentStatus -eq "False"){
        $MsgBody = $MsgBody + " <tr bgcolor='yellow'>"
        $Msghead = '<?php header("Status: 303 See Other"); ?>'
    }
    if ($s.CurrentStatus -eq "True"){
         $MsgBody = $MsgBody + " <tr> "
    }    
    $MsgBody = $MsgBody + "<td align=""center"" valign=""middle""> " + $s.FQDN +" </td>"
    $MsgBody = $MsgBody + "<td align=""center"" valign=""middle""> " + $s.OS +" </td>"
    $MsgBody = $MsgBody + "<td align=""center"" valign=""middle""> " + $s.Lastupdate +" </td>"
    $MsgBody = $MsgBody + "<td align=""center"" valign=""middle""> " + $s.Result +" </td>"
    $MsgBody = $MsgBody + "<td align=""center"" valign=""middle""> " + $s.Installed +" </td>"
    $MsgBody = $MsgBody + "<td align=""center"" valign=""middle""> " + $s.NotApplicableCount +" </td>"
    $MsgBody = $MsgBody + "<td align=""center"" valign=""middle""> " + $s.Notinstalled +" </td>"
    $MsgBody = $MsgBody + "<td align=""center"" valign=""middle""> " + $s.Pendingreboot +" </td>"
    $MsgBody = $MsgBody + "<td align=""center"" valign=""middle""> " + $s.Failed +" </td>"
    $MsgBody = $MsgBody + "<td align=""center"" valign=""middle""> " + $s.Unknown +" </td>"
    $MsgBody = $MsgBody + "</tr>" 
}
$MsgBody = $MsgBody + "</table><br>" # Finish the HTML table.

if (Test-Path $OutputFile){Remove-Item $OutputFile}
$Msghead+$MsgBody | Out-File -FilePath $OutputFile

# Nagios return result
if ($Nagios){
    ForEach ($s in wsuscompgroups($ComputerGroup)){
        if ($s.Count -eq 0){
            Write-Host "Critical: No hosts found, check computergroup"
	        exit 2            
        }
        if ($s.CurrentStatus -eq "False"){
            Write-Host "Warning: A host is missing updates"
	        exit 1            
        }
    }
    Write-Host "All good"
	exit 0
}
