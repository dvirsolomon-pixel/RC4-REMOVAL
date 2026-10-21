# Platform helpers. Windows PowerShell 5.1 has no $IsWindows/$IsLinux/$IsMacOS,
# so detection goes through [Environment] and the PowerShell edition.

function Get-AISPlatform {
    <#
    .SYNOPSIS
        Returns 'Windows', 'Linux' or 'MacOS' for the running process.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if ($PSVersionTable.PSEdition -eq 'Desktop') { return 'Windows' }
    if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) { return 'Windows' }
    $isMac = Get-Variable -Name 'IsMacOS' -ValueOnly -ErrorAction SilentlyContinue
    if ($isMac) { return 'MacOS' }
    return 'Linux'
}

function Test-AISElevated {
    <#
    .SYNOPSIS
        True when the current process runs elevated (Administrator on Windows, root elsewhere).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ((Get-AISPlatform) -eq 'Windows') {
        try {
            $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
            $principal = New-Object System.Security.Principal.WindowsPrincipal -ArgumentList $identity
            return [bool]$principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
        }
        catch {
            return $false
        }
    }
    return ([System.Environment]::UserName -eq 'root')
}
