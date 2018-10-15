$lastCheck = (Get-Date).AddSeconds(-2) 
while ($true) 
{
    $thisCheck = Get-Date 
    Get-EventLog -LogName Application -After $lastCheck -ErrorAction Ignore | Where-Object { ($_.Source -like '*Dynamics*' -or $_.Source -eq $SqlServiceName) -and $_.EntryType -eq "Error" -and $_.EntryType -ne "0" } | Select-Object TimeGenerated, EntryType, Message | format-list
    $lastCheck = $thisCheck 
    Start-Sleep -Seconds 2
}
