$lastCheck = (Get-Date).AddSeconds(-2) 
Write-Host "Starting EventLog Monitor"

########################################################################################################
### Setup EventLog to Monitor
########################################################################################################
$ComputerName   = "."                  ### LocalHost
$EventLogName   = "Application"        ### Application Event Log
$EventLogSource = ""                   ### Source cannot be filtered

########################################################################################################
### Setup Sources to Filter
########################################################################################################
### Get All Event Source for the selected Event Log
$EventLogSources = (Get-ChildItem HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\$($EventLogName)).pschildname

### Create array of EventSources to monitor in Global variable / need to be global so ObjectEvent can pick it up
$Global:EventLogSourcesToMonitor = $EventLogSources | where-object { ($_ -ilike "*Dynamics*") -or ($_ -ilike "MSSQL`$*")}
Write-Host "Monitoring EventSources from EventLog[$($EventLogName)]:"
foreach($EventLogSourceToMonitor in $Global:EventLogSourcesToMonitor){
    Write-Host "- $($EventLogSourceToMonitor)"
}
Write-Host ""

########################################################################################################
### Create the EventLog Object
########################################################################################################
### Initialize the LastEventLogIndex
$Global:LastEventLogIndex = 0

### Initialize dotnet EventLog object
$EventLog = [System.Diagnostics.EventLog]::New($EventLogName, $ComputerName, $EventLogSource)

########################################################################################################
### Register to the EventLog event "EntryWritten"
########################################################################################################
Register-ObjectEvent -InputObject $EventLog `
                     -EventName "EntryWritten" `
                     -Action {
                                ### Save event in Global variable / Not required / Handy for debugging
                                $Global:LastEvent = $Event

                                ### Map the received to event to variable for cleaner code
                                $EventLogEntry = $Event.SourceEventArgs.Entry

                                ### !!! ATTENTION !!!
                                ### This part is uber-important due to how the EventLog works
                                ### When the EventLog is full, is Rolls-Over (default setting)
                                ### When the EventLog Rolls-Over, all previous events are retriggered
                                ### Checking the Index, which is unique will prevent old events from displaying again
                                ### Events are always triggered and processed in order, so no risk in missing events.
                                if ($EventLogEntry.Index -le $Global:LastEventLogIndex) { return }                                
                                $Global:LastEventLogIndex = $EventLogEntry.Index

                                ### Check if the Event is from a selected source, ifnot exit
                                ### The array.Contains ask more performance than the Index check, thats why its second
                                if (!($Global:EventLogSourcesToMonitor.Contains($EventLogEntry.Source))) { return } 
             
                                ### Profit! Print the received event
                                Write-Host "TimeGenerated : $($EventLogEntry.TimeGenerated)"
                                Write-Host "EventSource: $($EventLogEntry.Source)"
                                Write-Host "EntryType : $($EventLogEntry.EntryType)"
                                Write-Host "Message : "
                                Write-Host "$($EventLogEntry.Message)"
                                Write-Host ""
                             } | Out-Null

while ($true) 
{
    Start-Sleep -Seconds 60
}
