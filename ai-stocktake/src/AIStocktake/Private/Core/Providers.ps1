# System data providers used through the scan context.
#
# Collectors never call the registry, CIM, Get-Process or Get-NetTCPConnection
# directly. They call:
#   $Ctx.Registry.GetUninstallEntries('HKCU'|'HKLM' [, $UserProfile])
#   $Ctx.Processes.GetSnapshot()
#   $Ctx.Listeners.GetListeningPorts()
# Each provider exists in two modes:
#   Real    - reads the live system (Windows APIs; best effort on Linux/macOS).
#   Fixture - reads JSON snapshots from <Root>/system/ so tests run anywhere.
# Missing fixture files mean "no data" (empty array), not an error.
#
# Output records are plain PSCustomObjects with a fixed allowlist of fields.
# WARNING: process CommandLine is RAW and may contain secrets. Collectors must
# pass it through the redactor (S1) before storing anything derived from it.

function Get-AISFixtureRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $FixtureDir,
        [Parameter(Mandatory = $true)] [string] $FileName
    )

    $path = Join-Path -Path (Join-Path -Path $FixtureDir -ChildPath 'system') -ChildPath $FileName
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return , @() }
    $data = Read-AISJsonFile -LiteralPath $path
    if ($null -eq $data) { return , @() }
    return , @($data)
}

function Get-AISFieldValue {
    # Reads a property that may be missing (PSCustomObject or dictionary).
    [CmdletBinding()]
    param(
        [AllowNull()] [object] $InputObject,
        [Parameter(Mandatory = $true)] [string] $Name
    )

    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) { return $InputObject[$Name] }
        return $null
    }
    $prop = $InputObject.PSObject.Properties[$Name]
    if ($prop) { return $prop.Value }
    return $null
}

function ConvertTo-AISUninstallRecord {
    [CmdletBinding()]
    param(
        [AllowNull()] [object] $Source,
        [string] $Hive,
        [string] $KeyName
    )

    if (-not $KeyName) { $KeyName = [string](Get-AISFieldValue -InputObject $Source -Name 'KeyName') }
    return [pscustomobject]@{
        PSTypeName      = 'AIS.UninstallEntry'
        Hive            = $Hive
        KeyName         = $KeyName
        DisplayName     = [string](Get-AISFieldValue -InputObject $Source -Name 'DisplayName')
        DisplayVersion  = [string](Get-AISFieldValue -InputObject $Source -Name 'DisplayVersion')
        Publisher       = [string](Get-AISFieldValue -InputObject $Source -Name 'Publisher')
        InstallLocation = [string](Get-AISFieldValue -InputObject $Source -Name 'InstallLocation')
        InstallDate     = [string](Get-AISFieldValue -InputObject $Source -Name 'InstallDate')
    }
}

function New-AISRegistryProvider {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Real', 'Fixture')]
        [string] $Mode,

        [string] $FixtureDir,

        [string] $CurrentUserName
    )

    $provider = [pscustomobject]@{
        PSTypeName      = 'AIS.RegistryProvider'
        Mode            = $Mode
        FixtureDir      = $FixtureDir
        CurrentUserName = $CurrentUserName
    }
    $provider | Add-Member -MemberType ScriptMethod -Name 'GetUninstallEntries' -Value {
        param([string] $Hive, [object] $UserProfile)
        if (@('HKCU', 'HKLM') -notcontains $Hive) {
            throw (New-AISSafeException -Code 'InvalidHive' -Message 'Hive must be HKCU or HKLM.')
        }
        $profileName = [string](Get-AISFieldValue -InputObject $UserProfile -Name 'Name')
        if ($this.Mode -eq 'Fixture') {
            $file = 'registry.' + $Hive + '.json'
            if ($Hive -eq 'HKCU' -and $profileName -and $profileName -ne $this.CurrentUserName) {
                $file = 'registry.HKCU.' + $profileName + '.json'
            }
            $records = Get-AISFixtureRecord -FixtureDir $this.FixtureDir -FileName $file
            $result = @()
            foreach ($r in $records) { $result += (ConvertTo-AISUninstallRecord -Source $r -Hive $Hive) }
            return , $result
        }
        return , @(Get-AISRealUninstallEntry -Hive $Hive -UserProfile $UserProfile -CurrentUserName $this.CurrentUserName)
    }
    return $provider
}

function Get-AISRealUninstallEntry {
    [CmdletBinding()]
    param(
        [string] $Hive,
        [object] $UserProfile,
        [string] $CurrentUserName
    )

    if ((Get-AISPlatform) -ne 'Windows') { return @() }
    $sub = 'Software\Microsoft\Windows\CurrentVersion\Uninstall'
    $roots = @()
    if ($Hive -eq 'HKLM') {
        $roots = @('Registry::HKEY_LOCAL_MACHINE\' + $sub, 'Registry::HKEY_LOCAL_MACHINE\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall')
    }
    else {
        $profileName = [string](Get-AISFieldValue -InputObject $UserProfile -Name 'Name')
        $sid = [string](Get-AISFieldValue -InputObject $UserProfile -Name 'Sid')
        if (-not $profileName -or $profileName -eq $CurrentUserName) {
            $roots = @('Registry::HKEY_CURRENT_USER\' + $sub)
        }
        elseif ($sid) {
            # Only hives that are already loaded (logged-on users) are visible; nothing is loaded by the scanner.
            $roots = @('Registry::HKEY_USERS\' + $sid + '\' + $sub)
        }
    }
    $result = @()
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($key in (Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue)) {
            $values = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction SilentlyContinue
            if ($null -eq $values) { continue }
            $result += (ConvertTo-AISUninstallRecord -Source $values -Hive $Hive -KeyName $key.PSChildName)
        }
    }
    return $result
}

function ConvertTo-AISProcessRecord {
    [CmdletBinding()]
    param([AllowNull()] [object] $Source)

    $processIdValue = Get-AISFieldValue -InputObject $Source -Name 'ProcessId'
    $parentValue = Get-AISFieldValue -InputObject $Source -Name 'ParentProcessId'
    return [pscustomobject]@{
        PSTypeName      = 'AIS.ProcessRecord'
        ProcessId       = $(if ($null -ne $processIdValue) { [int]$processIdValue } else { $null })
        ParentProcessId = $(if ($null -ne $parentValue) { [int]$parentValue } else { $null })
        Name            = [string](Get-AISFieldValue -InputObject $Source -Name 'Name')
        ExecutablePath  = [string](Get-AISFieldValue -InputObject $Source -Name 'ExecutablePath')
        CommandLine     = [string](Get-AISFieldValue -InputObject $Source -Name 'CommandLine')
    }
}

function New-AISProcessProvider {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Real', 'Fixture')]
        [string] $Mode,

        [string] $FixtureDir
    )

    $provider = [pscustomobject]@{
        PSTypeName = 'AIS.ProcessProvider'
        Mode       = $Mode
        FixtureDir = $FixtureDir
    }
    $provider | Add-Member -MemberType ScriptMethod -Name 'GetSnapshot' -Value {
        if ($this.Mode -eq 'Fixture') {
            $result = @()
            foreach ($r in (Get-AISFixtureRecord -FixtureDir $this.FixtureDir -FileName 'processes.json')) {
                $result += (ConvertTo-AISProcessRecord -Source $r)
            }
            return , $result
        }
        return , @(Get-AISRealProcess)
    }
    return $provider
}

function Get-AISRealProcess {
    [CmdletBinding()]
    param()

    $result = @()
    if ((Get-AISPlatform) -eq 'Windows') {
        foreach ($p in (Get-CimInstance -ClassName Win32_Process -ErrorAction Stop)) {
            $result += (ConvertTo-AISProcessRecord -Source $p)
        }
        return $result
    }
    foreach ($p in (Get-Process -ErrorAction SilentlyContinue)) {
        $cmd = $null
        $cmdProp = $p.PSObject.Properties['CommandLine']
        if ($cmdProp) { $cmd = $cmdProp.Value }
        $result += (ConvertTo-AISProcessRecord -Source @{
                ProcessId      = $p.Id
                Name           = $p.ProcessName
                ExecutablePath = $p.Path
                CommandLine    = $cmd
            })
    }
    return $result
}

function ConvertTo-AISListenerRecord {
    [CmdletBinding()]
    param([AllowNull()] [object] $Source)

    $port = Get-AISFieldValue -InputObject $Source -Name 'LocalPort'
    $owner = Get-AISFieldValue -InputObject $Source -Name 'ProcessId'
    if ($null -eq $owner) { $owner = Get-AISFieldValue -InputObject $Source -Name 'OwningProcess' }
    return [pscustomobject]@{
        PSTypeName   = 'AIS.ListenerRecord'
        Protocol     = 'TCP'
        LocalAddress = [string](Get-AISFieldValue -InputObject $Source -Name 'LocalAddress')
        LocalPort    = $(if ($null -ne $port) { [int]$port } else { $null })
        ProcessId    = $(if ($null -ne $owner -and [string]$owner -ne '') { [int]$owner } else { $null })
    }
}

function New-AISListenerProvider {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Real', 'Fixture')]
        [string] $Mode,

        [string] $FixtureDir
    )

    $provider = [pscustomobject]@{
        PSTypeName = 'AIS.ListenerProvider'
        Mode       = $Mode
        FixtureDir = $FixtureDir
    }
    $provider | Add-Member -MemberType ScriptMethod -Name 'GetListeningPorts' -Value {
        if ($this.Mode -eq 'Fixture') {
            $result = @()
            foreach ($r in (Get-AISFixtureRecord -FixtureDir $this.FixtureDir -FileName 'listeners.json')) {
                $result += (ConvertTo-AISListenerRecord -Source $r)
            }
            return , $result
        }
        return , @(Get-AISRealListeningPort)
    }
    return $provider
}

function Get-AISRealListeningPort {
    [CmdletBinding()]
    param()

    if ((Get-AISPlatform) -eq 'Windows') {
        # Resolved dynamically: the NetTCPIP module is Windows-only and absent on Server Core images.
        $netTcp = Get-Command -Name 'Get-NetTCPConnection' -ErrorAction SilentlyContinue
        if ($netTcp) {
            $result = @()
            foreach ($c in (& $netTcp -State Listen -ErrorAction Stop)) {
                $result += (ConvertTo-AISListenerRecord -Source $c)
            }
            return $result
        }
        $text = (& netstat.exe -ano -p TCP) -join "`n"
        return @(ConvertFrom-AISNetstatOutput -Text $text)
    }
    if (Get-Command -Name 'ss' -CommandType Application -ErrorAction SilentlyContinue) {
        $text = (& ss -ltnH 2>$null) -join "`n"
        return @(ConvertFrom-AISSsOutput -Text $text)
    }
    return @()
}

function Split-AISEndpoint {
    # "127.0.0.1:11434" / "[::]:1234" / "*:80" -> @(address, port)
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [string] $Endpoint)

    $idx = $Endpoint.LastIndexOf(':')
    if ($idx -lt 0) { return $null }
    $addr = $Endpoint.Substring(0, $idx).Trim('[', ']')
    $portText = $Endpoint.Substring($idx + 1)
    $port = 0
    if (-not [int]::TryParse($portText, [ref]$port)) { return $null }
    if ($addr -eq '*') { $addr = '0.0.0.0' }
    $pct = $addr.IndexOf('%')
    if ($pct -gt 0) { $addr = $addr.Substring(0, $pct) }
    return @($addr, $port)
}

function ConvertFrom-AISNetstatOutput {
    <#
    .SYNOPSIS
        Parses Windows "netstat -ano -p TCP" output into listener records.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [AllowEmptyString()] [string] $Text)

    $result = @()
    foreach ($line in ($Text -split "`r?`n")) {
        $cols = @($line.Trim() -split '\s+')
        if ($cols.Count -lt 5 -or $cols[0] -notmatch '^TCP') { continue }
        if ($cols[3] -notmatch '^LISTEN') { continue }
        $ep = Split-AISEndpoint -Endpoint $cols[1]
        if ($null -eq $ep) { continue }
        $result += (ConvertTo-AISListenerRecord -Source @{ LocalAddress = $ep[0]; LocalPort = $ep[1]; ProcessId = $cols[4] })
    }
    return $result
}

function ConvertFrom-AISSsOutput {
    <#
    .SYNOPSIS
        Parses Linux "ss -ltnH" output (State Recv-Q Send-Q Local Peer [Process]).
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [AllowEmptyString()] [string] $Text)

    $result = @()
    foreach ($line in ($Text -split "`r?`n")) {
        $cols = @($line.Trim() -split '\s+')
        if ($cols.Count -lt 4 -or $cols[0] -ne 'LISTEN') { continue }
        $ep = Split-AISEndpoint -Endpoint $cols[3]
        if ($null -eq $ep) { continue }
        $owner = $null
        $m = [regex]::Match($line, 'pid=(\d+)')
        if ($m.Success) { $owner = $m.Groups[1].Value }
        $result += (ConvertTo-AISListenerRecord -Source @{ LocalAddress = $ep[0]; LocalPort = $ep[1]; ProcessId = $owner })
    }
    return $result
}
