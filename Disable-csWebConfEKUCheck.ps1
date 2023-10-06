
<#PSScriptInfo

.VERSION 1.4

.GUID 60a7a321-2003-4563-b6d5-782317858ce6

.AUTHOR David Paulino

.COMPANYNAME UC Lobby

.COPYRIGHT

.TAGS Certificates Lync LyncServer SkypeForBusiness SfBServer Registry

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
  Version 1.0 – 2017/05/24 - Initial release.
  Version 1.1 – 2017/05/30 - Additional check if the registry key was previously configured.
  Version 1.2 - 2017/06/02 - Check if the Front End has a Edge Pool associated for media and if the Certificate already includes Client and Server Authentication in EKU.
  Version 1.3 - 2017/06/27 - Added switch type Dword to Set-ItemProperty.
  Version 1.4 - 2019/01/07 - Fixed issue if path was not found while adding the reg key.
  Version 1.5 - 2023/10/06 - Updated to publish in PowerShell Gallery.


.PRIVATEDATA

#>

<# 

.DESCRIPTION 
 This script disables the EKU check for Lync/SfB Web Conferencing Service. 
 
 Lync/SfB Server: Event 41026, LS Data MCU after May 2017 .NET Framework update
 https://uclobby.com/2017/05/24/lync-sfb-server-event-41026-ls-data-mcu-after-may-2017-net-framework-update/

#> 
Import-Module Lync
$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Description."
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Description."
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
$RTCDATAMCU = Get-wmiobject win32_service | ?{$_.name -eq 'RTCDATAMCU'}
if($RTCDATAMCU -ne $null){
    $RTCDATAMCUPATH = (($RTCDATAMCU | select pathname).pathname).Replace("`"","")
    if ($RTCDATAMCUPATH -like "*DataMCUSvc.exe*") {
        $CSVersion = Get-CsServerVersion

        if($CSVersion  -like "*4.0.7577.0*"){
            Write-Host "Microsoft Lync Server 2010" -ForegroundColor Green
            $regPath = "HKLM:\SOFTWARE\Microsoft\.NETFramework\v2.0.50727\System.Net.ServicePointManager.RequireCertificateEKUs"
        } elseif ($CSVersion  -like "*5.0.8308.0*") {
            Write-Host "Microsoft Lync Server 2013" -ForegroundColor Green
            $regPath = "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319\System.Net.ServicePointManager.RequireCertificateEKUs"
        } elseif ($CSVersion  -like "*6.0.9319.0*") {
            Write-Host "Skype for Business Server 2015" -ForegroundColor Green
            $regPath = "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319\System.Net.ServicePointManager.RequireCertificateEKUs"
        }
        #Get the Edge Pool associated with this Front End
        $confFqdn = "ConferencingServer:"+(Get-CsComputer| ?{$_.Fqdn -eq [System.Net.Dns]::GetHostByName((hostname)).HostName }).pool
        $edgePool = Get-CsService -EdgeServer | ?{$_.DependentServiceList -contains $confFqdn }
        if($edgePool){
            $needRegKey = $true
            $edgeServers = Get-CsComputer -Pool $edgePool.PoolFqdn | Select Fqdn
            foreach ($edgeServer in $edgeServers){
                try{
                    Write-Host  $edgeServer.Fqdn: "Checking for client authentication in certificate..." -ForegroundColor Cyan
                    $tcpsocket = New-Object Net.Sockets.TcpClient($edgeServer.Fqdn, 4443) -ErrorAction Stop
                    if($tcpsocket)
                    {
                        Write-Host  $edgeServer.Fqdn: "Connection established" -ForegroundColor Green 
                        $tcpstream = $tcpsocket.GetStream()
                        $sslStream = New-Object System.Net.Security.SslStream($tcpstream,$false)
                        $sslStream.AuthenticateAsClient($edgeServer.Fqdn)
                        $certinfo = New-Object system.security.cryptography.x509certificates.x509certificate2($sslStream.RemoteCertificate)
                        if ($null -ne ($certinfo.EnhancedKeyUsageList | ?{$_.FriendlyName -eq "Client Authentication"})){
                            Write-Host $edgeServer.Fqdn ": Client authentication already exists in the certificate." -ForegroundColor Green
                            $needRegKey = $false
                        } else {
                            Write-Host $edgeServer.Fqdn ": Client authentication missing from certificate." -ForegroundColor Yellow
                        }
                        $tcpsocket.Dispose()
                        $sslStream.Dispose()
                    }
                } catch {
                    Write-Host $edgeServer.Fqdn ": Connection failed -" $error[0].Exception.Message.Substring($error[0].Exception.Message.IndexOf(":")+2) -ForegroundColor Red
                }
            }
            #Check it the registry key was previously added.
            try {
                $regPresent = Get-ItemProperty -Path $regPath -ErrorAction Stop | Select-Object -ExpandProperty $RTCDATAMCUPATH -ErrorAction Stop 
            }
            catch {
                $regPresent = -1
            }
            if($needRegKey){
                if($regPresent -ne 0){
                    Write-Host "Web Conferencing Service found in:" $RTCDATAMCUPATH -ForegroundColor Cyan
                    $title = $ADObject.DisplayName
                    $message = "Do you want to add the registry key to disable the EKU check for DATA MCU Service?"
                    $result = $host.ui.PromptForChoice($title, $message, $options, 1)
                    switch ($result) {
                        0{
                            if(!(Test-Path $regPath)){
                                New-Item -Path $regPath | Out-Null
                            }
                            Set-ItemProperty -Path $regPath -Name $RTCDATAMCUPATH -Value 0 -Type DWord
                            Write-Host "Registry Key added, please restart the Web Conferencing Service" -ForegroundColor Yellow
                        }1{
                            Write-Host "Please manually add the registry key: " -ForegroundColor Yellow
                            Write-Host "Set-ItemProperty -Path $regPath -Name ""$RTCDATAMCUPATH"" -Value 0 -Type DWord" -ForegroundColor Cyan
                        }
                    }
                }
                else {
                    Write-Host "The registry key to disable EKU check for Web Conferencing was already configured." -ForegroundColor Green
                }
            } elseif($regPresent -eq 0){
                $title = $ADObject.DisplayName
                $message = "Do you want to remove the registry key for disable EKU check for DATA MCU Service?"
                $result = $host.ui.PromptForChoice($title, $message, $options, 1)
                switch ($result) {
                    0{
                        Remove-ItemProperty -Path $regPath -Name $RTCDATAMCUPATH
                        Write-Host "Registry key removed, please restart the Web Conferencing Service." -ForegroundColor Yellow
                    }
                }
            }
        } else {
            Write-Host "This Front End isn't associated to an Edge Pool." -ForegroundColor Green
        }
    }
 }
 else {
    Write-Host "Web Conferencing Service not found on this server." -ForegroundColor Yellow
 }