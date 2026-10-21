# ScanContext: the only door collectors have to the machine.
#
# Real mode   : roots come from [Environment]::GetFolderPath, providers query the system.
# Fixture mode: New-AISScanContext -Root <dir>. Every root maps inside <dir>
#               using a Windows-like layout, providers read <dir>/system/*.json,
#               and <dir>/fixture.json supplies host facts. Layout:
#
#   <dir>/fixture.json                       (optional, see Get-AISFixtureManifest)
#   <dir>/Users/<user>/                      {UserProfile}
#   <dir>/Users/<user>/AppData/Roaming/      {AppData}
#   <dir>/Users/<user>/AppData/Local/        {LocalAppData}
#   <dir>/ProgramData/                       {ProgramData}
#   <dir>/Program Files/                     {ProgramFiles}
#   <dir>/Program Files (x86)/               {ProgramFilesX86}
#   <dir>/system/registry.HKLM.json          uninstall entries (HKLM)
#   <dir>/system/registry.HKCU.json          uninstall entries (current fixture user)
#   <dir>/system/registry.HKCU.<user>.json   uninstall entries (other profiles, machine-wide)
#   <dir>/system/processes.json              process snapshot
#   <dir>/system/listeners.json              TCP listeners

$script:AISExcludedProfileNames = @('Public', 'Default', 'Default User', 'All Users', 'defaultuser0', 'WDAGUtilityAccount')

function Get-AISFixtureManifest {
    <#
    .SYNOPSIS
        Reads <Root>/fixture.json and applies defaults.
    .DESCRIPTION
        Supported keys (all optional):
          hostName   (default 'FIXTURE-HOST')
          userName   (default 'fixtureuser'; must exist under Users/ to be scanned)
          os         { family: Windows|Linux|MacOS, version }  (default Windows 10.0.26100)
          powershell { version, edition }                      (default 5.1.26100.1 / Desktop)
          isElevated (default false)
          now        ISO-8601 UTC timestamp used as the scan clock (default: real time)
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [string] $Root)

    $manifest = $null
    $file = Join-Path -Path $Root -ChildPath 'fixture.json'
    if (Test-Path -LiteralPath $file -PathType Leaf) { $manifest = Read-AISJsonFile -LiteralPath $file }

    $os = Get-AISFieldValue -InputObject $manifest -Name 'os'
    $ps = Get-AISFieldValue -InputObject $manifest -Name 'powershell'
    $now = Get-AISFieldValue -InputObject $manifest -Name 'now'
    $nowUtc = $null
    if ($now -is [datetime]) {
        $nowUtc = $now.ToUniversalTime()
        if ($now.Kind -eq [System.DateTimeKind]::Utc) { $nowUtc = $now }
    }
    elseif ($now) {
        $styles = [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal
        $nowUtc = [datetime]::Parse([string]$now, [System.Globalization.CultureInfo]::InvariantCulture, $styles)
    }

    $family = [string](Get-AISFieldValue -InputObject $os -Name 'family')
    if (@('Windows', 'Linux', 'MacOS') -notcontains $family) { $family = 'Windows' }

    return [pscustomobject]@{
        HostName          = (Get-AISValueOrDefault (Get-AISFieldValue -InputObject $manifest -Name 'hostName') 'FIXTURE-HOST')
        UserName          = (Get-AISValueOrDefault (Get-AISFieldValue -InputObject $manifest -Name 'userName') 'fixtureuser')
        OsFamily          = $family
        OsVersion         = (Get-AISValueOrDefault (Get-AISFieldValue -InputObject $os -Name 'version') '10.0.26100')
        PowerShellVersion = (Get-AISValueOrDefault (Get-AISFieldValue -InputObject $ps -Name 'version') '5.1.26100.1')
        PowerShellEdition = (Get-AISValueOrDefault (Get-AISFieldValue -InputObject $ps -Name 'edition') 'Desktop')
        IsElevated        = [bool](Get-AISFieldValue -InputObject $manifest -Name 'isElevated')
        NowUtc            = $nowUtc
    }
}

function Get-AISValueOrDefault {
    [CmdletBinding()]
    param([AllowNull()] [object] $Value, [AllowNull()] [object] $Default)

    if ($null -eq $Value -or [string]$Value -eq '') { return $Default }
    return [string]$Value
}

function New-AISProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $Name,
        [Parameter(Mandatory = $true)] [string] $UserProfilePath,
        [Parameter(Mandatory = $true)] [System.Collections.IDictionary] $MachineRoots,
        [string] $Sid,
        [bool] $IsCurrent,
        [string] $AppData,
        [string] $LocalAppData
    )

    if (-not $AppData) { $AppData = Join-Path -Path (Join-Path -Path $UserProfilePath -ChildPath 'AppData') -ChildPath 'Roaming' }
    if (-not $LocalAppData) { $LocalAppData = Join-Path -Path (Join-Path -Path $UserProfilePath -ChildPath 'AppData') -ChildPath 'Local' }
    $roots = [ordered]@{
        UserProfile  = $UserProfilePath
        AppData      = $AppData
        LocalAppData = $LocalAppData
    }
    foreach ($k in $MachineRoots.Keys) { $roots[$k] = $MachineRoots[$k] }
    return [pscustomobject]@{
        PSTypeName = 'AIS.Profile'
        Name       = $Name
        Sid        = $(if ($Sid) { $Sid } else { $null })
        IsCurrent  = $IsCurrent
        Roots      = $roots
    }
}

function New-AISScanContext {
    <#
    .SYNOPSIS
        Builds the scan context (real system, or fixture when -Root is given).
    .OUTPUTS
        AIS.ScanContext with: Mode ('user'|'machine'), IsFixture, FixtureRoot,
        Platform, Os {family, version}, PowerShell {version, edition}, HostName,
        UserName, IsElevated, PrivacyMode, Roots (current user), Profiles[],
        Registry, Processes, Listeners, Clock (scriptblock -> UTC DateTime),
        FingerprintKey (byte[]; never serialize the context), InitErrors[].
        Method: Now() -> UTC DateTime.
    #>
    [CmdletBinding()]
    param(
        [string] $Root,

        [switch] $MachineWide,

        [switch] $PrivacyMode,

        [byte[]] $FingerprintKey
    )

    $initErrors = New-Object System.Collections.Generic.List[object]
    if (-not $FingerprintKey) { $FingerprintKey = New-AISRandomKey -Length 32 }

    if ($Root) {
        $rootFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Root)
        if (-not (Test-Path -LiteralPath $rootFull -PathType Container)) {
            throw (New-AISSafeException -Code 'FixtureRootNotFound' -Message ('Fixture root not found: ' + $Root))
        }
        $manifest = Get-AISFixtureManifest -Root $rootFull
        $usersRoot = Join-Path -Path $rootFull -ChildPath 'Users'
        $machineRoots = [ordered]@{
            ProgramData     = (Join-Path -Path $rootFull -ChildPath 'ProgramData')
            ProgramFiles    = (Join-Path -Path $rootFull -ChildPath 'Program Files')
            ProgramFilesX86 = (Join-Path -Path $rootFull -ChildPath 'Program Files (x86)')
            SystemDrive     = $rootFull
            UsersRoot       = $usersRoot
        }
        $isFixture = $true
        $platform = $manifest.OsFamily
        $osInfo = [ordered]@{ family = $manifest.OsFamily; version = $manifest.OsVersion }
        $psInfo = [ordered]@{ version = $manifest.PowerShellVersion; edition = $manifest.PowerShellEdition }
        $hostName = $manifest.HostName
        $userName = $manifest.UserName
        $isElevated = $manifest.IsElevated
        $fixedNow = $manifest.NowUtc
        $providerMode = 'Fixture'

        $current = New-AISProfile -Name $userName -UserProfilePath (Join-Path -Path $usersRoot -ChildPath $userName) -MachineRoots $machineRoots -IsCurrent $true
        $allProfiles = @()
        if (Test-Path -LiteralPath $usersRoot -PathType Container) {
            foreach ($dir in (Get-ChildItem -LiteralPath $usersRoot -Directory | Sort-Object -Property Name)) {
                if ($script:AISExcludedProfileNames -contains $dir.Name) { continue }
                $allProfiles += (New-AISProfile -Name $dir.Name -UserProfilePath $dir.FullName -MachineRoots $machineRoots -IsCurrent ($dir.Name -eq $userName))
            }
        }
    }
    else {
        $isFixture = $false
        $rootFull = $null
        $platform = Get-AISPlatform
        $osInfo = [ordered]@{ family = $platform; version = [System.Environment]::OSVersion.Version.ToString() }
        $psInfo = [ordered]@{ version = $PSVersionTable.PSVersion.ToString(); edition = [string]$PSVersionTable.PSEdition }
        $hostName = [System.Environment]::MachineName
        $userName = [System.Environment]::UserName
        $isElevated = Test-AISElevated
        $fixedNow = $null
        $providerMode = 'Real'

        $sf = [System.Environment+SpecialFolder]
        $userProfilePath = [System.Environment]::GetFolderPath($sf::UserProfile)
        $machineRoots = [ordered]@{
            ProgramData     = [System.Environment]::GetFolderPath($sf::CommonApplicationData)
            ProgramFiles    = [System.Environment]::GetFolderPath($sf::ProgramFiles)
            ProgramFilesX86 = [System.Environment]::GetFolderPath($sf::ProgramFilesX86)
            SystemDrive     = $(if ($platform -eq 'Windows') { [System.IO.Path]::GetPathRoot($userProfilePath) } else { '/' })
            UsersRoot       = (Split-Path -Path $userProfilePath -Parent)
        }
        $current = New-AISProfile -Name $userName -UserProfilePath $userProfilePath -MachineRoots $machineRoots -IsCurrent $true `
            -AppData ([System.Environment]::GetFolderPath($sf::ApplicationData)) -LocalAppData ([System.Environment]::GetFolderPath($sf::LocalApplicationData))
        $allProfiles = $null
    }

    $mode = 'user'
    $profiles = @($current)
    if ($MachineWide) {
        if (-not $isElevated) {
            $initErrors.Add((New-AISScanError -Collector 'Core' -Code 'NotElevated' -Message 'Machine-wide scan requested without administrative rights; only the current user profile was scanned.'))
        }
        else {
            $mode = 'machine'
            if ($null -eq $allProfiles) {
                try {
                    $allProfiles = @(Get-AISRealProfile -MachineRoots $machineRoots -CurrentUserName $userName -Platform $platform)
                }
                catch {
                    $info = Get-AISSafeErrorInfo -ErrorObject $_ -DefaultCode 'ProfileEnumerationFailed' -Context 'Profile enumeration'
                    $initErrors.Add((New-AISScanError -Collector 'Core' -Code $info.Code -Message $info.Message))
                    $allProfiles = @()
                }
            }
            # Keep the current user's real roots (folder redirection) and add the others.
            $profiles = @($current)
            foreach ($p in $allProfiles) {
                if ($p.Name -ne $current.Name) { $profiles += $p }
            }
        }
    }

    $clock = { [datetime]::UtcNow }
    if ($null -ne $fixedNow) {
        $clock = { $fixedNow }.GetNewClosure()
    }

    $context = [pscustomobject]@{
        PSTypeName     = 'AIS.ScanContext'
        Mode           = $mode
        IsFixture      = $isFixture
        FixtureRoot    = $rootFull
        Platform       = $platform
        Os             = $osInfo
        PowerShell     = $psInfo
        HostName       = $hostName
        UserName       = $userName
        IsElevated     = [bool]$isElevated
        PrivacyMode    = [bool]$PrivacyMode
        Roots          = $current.Roots
        Profiles       = $profiles
        Registry       = (New-AISRegistryProvider -Mode $providerMode -FixtureDir $rootFull -CurrentUserName $userName)
        Processes      = (New-AISProcessProvider -Mode $providerMode -FixtureDir $rootFull)
        Listeners      = (New-AISListenerProvider -Mode $providerMode -FixtureDir $rootFull)
        Clock          = $clock
        FingerprintKey = $FingerprintKey
        InitErrors     = $initErrors.ToArray()
    }
    $context | Add-Member -MemberType ScriptMethod -Name 'Now' -Value { & $this.Clock }
    # Keep the key out of default formatting output.
    $context | Add-Member -MemberType MemberSet -Name PSStandardMembers -Value ([System.Management.Automation.PSMemberInfo[]]@(
            New-Object System.Management.Automation.PSPropertySet -ArgumentList 'DefaultDisplayPropertySet', ([string[]]@('Mode', 'IsFixture', 'Platform', 'HostName', 'UserName', 'IsElevated', 'PrivacyMode'))
        ))
    return $context
}

function Get-AISRealProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [System.Collections.IDictionary] $MachineRoots,
        [string] $CurrentUserName,
        [string] $Platform
    )

    $result = @()
    if ($Platform -eq 'Windows') {
        $cim = @(Get-CimInstance -ClassName Win32_UserProfile -Filter 'Special = False' -ErrorAction Stop)
        foreach ($p in $cim) {
            if (-not $p.LocalPath) { continue }
            $name = Split-Path -Path $p.LocalPath -Leaf
            if ($script:AISExcludedProfileNames -contains $name) { continue }
            $result += (New-AISProfile -Name $name -UserProfilePath $p.LocalPath -MachineRoots $MachineRoots -Sid $p.SID -IsCurrent ($name -eq $CurrentUserName))
        }
        return $result
    }
    $usersRoot = [string]$MachineRoots['UsersRoot']
    if ($usersRoot -and (Test-Path -LiteralPath $usersRoot -PathType Container)) {
        foreach ($dir in (Get-ChildItem -LiteralPath $usersRoot -Directory -ErrorAction SilentlyContinue)) {
            if ($script:AISExcludedProfileNames -contains $dir.Name) { continue }
            $result += (New-AISProfile -Name $dir.Name -UserProfilePath $dir.FullName -MachineRoots $MachineRoots -IsCurrent ($dir.Name -eq $CurrentUserName) `
                    -AppData (Join-Path -Path $dir.FullName -ChildPath '.config') -LocalAppData (Join-Path -Path (Join-Path -Path $dir.FullName -ChildPath '.local') -ChildPath 'share'))
        }
    }
    return $result
}
