# Safe exceptions.
#
# Any exception message may end up in errors[] of the scan result. Messages of
# arbitrary exceptions can quote file content (ConvertFrom-Json does), so the
# orchestrator only copies a message into the output when the exception was
# created by New-AISSafeException, i.e. the author declared it safe. All other
# exceptions are reported with a generic message naming only the exception type.

function New-AISSafeException {
    <#
    .SYNOPSIS
        Creates an exception whose message is declared safe for the scan output.
    .PARAMETER Code
        Short machine-readable code (PascalCase, letters and digits).
    .PARAMETER Message
        Human-readable message. Must never contain configuration values or
        secrets. Paths are allowed (privacy mode redacts user names in them).
    .EXAMPLE
        throw (New-AISSafeException -Code 'ConfigUnreadable' -Message "Cannot read $path")
    #>
    [CmdletBinding()]
    [OutputType([System.Exception])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[A-Za-z][A-Za-z0-9]{1,63}$')]
        [string] $Code,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Message
    )

    $ex = New-Object System.InvalidOperationException -ArgumentList $Message
    $ex.Data['AIS.Safe'] = $true
    $ex.Data['AIS.Code'] = $Code
    return $ex
}

function Get-AISSafeErrorInfo {
    <#
    .SYNOPSIS
        Returns @{ Code; Message } for an ErrorRecord or Exception, using the
        original message only when it was created by New-AISSafeException.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object] $ErrorObject,

        [string] $DefaultCode = 'Failed',

        [string] $Context = 'Operation'
    )

    $ex = $ErrorObject
    if ($ErrorObject -is [System.Management.Automation.ErrorRecord]) { $ex = $ErrorObject.Exception }

    # Unwrap runtime wrappers (e.g. MethodInvocationException) to find a safe inner exception.
    $cursor = $ex
    while ($null -ne $cursor) {
        if ($cursor -is [System.Exception] -and $cursor.Data -and $cursor.Data.Contains('AIS.Safe') -and $cursor.Data['AIS.Safe'] -eq $true) {
            return @{ Code = [string]$cursor.Data['AIS.Code']; Message = [string]$cursor.Message }
        }
        if ($cursor -is [System.Exception]) { $cursor = $cursor.InnerException } else { $cursor = $null }
    }

    $typeName = 'UnknownError'
    if ($ex -is [System.Exception]) { $typeName = $ex.GetType().Name }
    return @{
        Code    = $DefaultCode
        Message = ($Context + ' failed with ' + $typeName + '. Details are withheld because they may contain configuration content.')
    }
}
