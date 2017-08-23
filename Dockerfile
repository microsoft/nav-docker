FROM microsoft/mssql-server-windows-developer

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Install the prerequisites first to be able reuse the cache when changing only the scripts.
# Temporary workaround for Windows DNS client weirdness (need to check if the issue is still present or not).
# Remove docker files from Sql server image
RUN Add-WindowsFeature Web-Server,web-AppInit,web-Asp-Net45,web-Windows-Auth,web-Dyn-Compression; \
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters' -Name ServerPriorityTimeLimit -Value 0 -Type DWord; \
    Remove-Item c:\license.txt; \
    Remove-Item c:\start.ps1; \
    Remove-Item c:\dockerfile; \
    Set-Service MSSQLSERVER -startuptype "manual"; \
    Set-Service SQLTELEMETRY -startuptype "manual"; \
    Set-Service SQLWriter -startuptype "manual"
    
COPY Run /Run/

# Copy Powershell config in place (for various NAV CmdLets to use SQL v13 DLLs)
RUN Copy-Item -Path C:\Run\powershell.exe.config -Destination C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe.Config -Force; \
    Copy-Item -Path C:\Run\powershell.exe.config -Destination C:\Windows\SysWOW64\Windowspowershell\v1.0\powershell.exe.Config -Force

HEALTHCHECK --interval=30s --timeout=10s CMD [ "powershell", ".\\Run\\HealthCheck.ps1" ]

EXPOSE 1433 80 8080 443 7045-7049

CMD .\Run\start.ps1
