# Uninstall functions and helpers copied from PR #1663 (https://github.com/chocolatey/choco/pull/1663/files)
# Until it is merged, there is no built-in way to uninstall a path from the user's PATH environment variable.
# Which is odd, because there is a built-in way to add a path to the user's PATH environment variable.

# Once merged, this script can be simplified to just the last line to match the one-liner in the install script.

function Uninstall-ChocolateyPath {
    param(
        [string] $PathToUninstall,
        [string] $PathType = 'User'
    )

    Write-FunctionCallLogMessage -Invocation $MyInvocation -Parameters $PSBoundParameters

    $paths = Parse-EnvPathList (Get-EnvironmentVariable -Name 'PATH' -Scope $pathType -PreserveVariables)
    $removeIndex = (IndexOf-EnvPath $paths $pathToUninstall)
    if ($removeIndex -ge 0) {
        Write-Host "Found $pathToUninstall in PATH environment variable. Removing..."

        $paths = [System.Collections.ArrayList] $paths
        $paths.RemoveAt($removeIndex)
        Set-EnvironmentVariable -Name 'PATH' -Value $(Format-EnvPathList $paths) -Scope $pathType
    }

    # Make change immediately available
    $paths = Parse-EnvPathList $env:PATH
    $removeIndex = (IndexOf-EnvPath $paths $pathToUninstall)
    if ($removeIndex -ge 0) {
        $paths = [System.Collections.ArrayList] $paths
        $paths.RemoveAt($removeIndex)
        $env:Path = Format-EnvPathList $paths
    }
}

function Parse-EnvPathList([string] $rawPathVariableValue) {
    # Using regex (for performance) which correctly splits at each semicolon unless the semicolon is inside double quotes.
    # Unlike semicolons, quotes are not allowed inside paths so there is thankfully no need to unescape them.
    # (Verified using Windows 10's environment variable editor.)
    # Blank path entries are preserved, such as those caused by a trailing semicolon.
    # This enables reserializing without gratuitous reformatting.
    $paths = $rawPathVariableValue -split '(?<=\G(?:[^;"]|"[^"]*")*);'

    # Remove quotes from each path if they are present
    for ($i = 0; $i -lt $paths.Length; $i++) {
        $path = $paths[$i]
        if ($path.Length -ge 2 -and $path.StartsWith('"', [StringComparison]::Ordinal) -and $path.EndsWith('"', [StringComparison]::Ordinal)) {
            $paths[$i] = $path.Substring(1, $path.Length - 2)
        }
    }

    return $paths
}

function Format-EnvPathList([string[]] $paths) {
    # Don't mutate the original (externally visible if the argument is not type-coerced),
    # but don't clone if mutation is unnecessary.
    $createdDefensiveCopy = $false

    # Add quotes to each path if necessary
    for ($i = 0; $i -lt $paths.Length; $i++) {
        $path = $paths[$i]
        if ($path -ne $null -and $path.Contains(';')) {
            if (-not $createdDefensiveCopy) {
                $createdDefensiveCopy = $true
                $paths = $paths.Clone()
            }
            $paths[$i] = '"' + $path + '"'
        }
    }

    return $paths -join ';'
}

function IndexOf-EnvPath([System.Collections.Generic.List[string]] $list, [string] $value) {
    $list.FindIndex({
            $value.Equals($args[0], [StringComparison]::OrdinalIgnoreCase)
        })
}

Uninstall-ChocolateyPath -PathToUninstall "$PSScriptRoot" -PathType 'User'
