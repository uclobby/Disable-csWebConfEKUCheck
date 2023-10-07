# Disable-csWebConfEKUCheck

This script disables the EKU check for Web Conferencing Server after the May 2017 .Net Framework update. Additional details in:
<br/>
<br/>&nbsp;&nbsp;Lync/SfB Server: Event 41026, LS Data MCU after May 2017 .NET Framework update
<br/>&nbsp;&nbsp;https://uclobby.com/2017/05/24/lync-sfb-server-event-41026-ls-data-mcu-after-may-2017-net-framework-update/
<br/>
<br/>Usage:
<br/>&nbsp;&nbsp;
Disable-csWebConfEKUCheck.ps1
<br/>
<br/>Currently the script doesn’t accept any parameter and it should be executed on the Front Ends.
<br/>
<br/>Change Log
<ul>
    <li>Version 1.0: 2017/05/24 - Initial release.</li>
    <li>Version 1.1: 2017/05/30 - Additional check if the registry key was previously configured.</li>
    <li>Version 1.2: 2017/06/02 - Check if the Front End has a Edge Pool associated for media and if the Certificate already includes Client and Server Authentication in EKU.</li>
    <li>Version 1.3: 2017/06/27 - Added switch type Dword to Set-ItemProperty.</li>
    <li>Version 1.4: 2019/01/07 - Fixed issue if path was not found while adding the reg key.</li>
    <li>Version 1.5: 2023/10/06 - Updated to publish in PowerShell Gallery.</li>
</ul>
