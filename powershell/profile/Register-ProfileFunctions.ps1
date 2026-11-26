<#
.SYNOPSIS
    Registers powershell/functions/*.ps1 for lazy global autoload.

.DESCRIPTION
    Parses each function file's AST for top-level function definitions and
    Set-Alias/New-Alias commands. Creates global stubs for each function so the
    file is imported into the session only on first use (via a dynamic module +
    Import-Module -Global). Aliases are registered immediately so short names
    like `rsb` resolve before the target file has ever been loaded.

    Exports (functions and aliases) are cached per file in
    %LOCALAPPDATA%\PowerShellSetup\cache\function-exports.json, keyed by size and
    last-write time, so unchanged files are not re-parsed on every startup.

    Files with no top-level functions (side-effect scripts such as
    Register-AzCompleter.ps1) are eager-dot-sourced at registration time.

    Dot-source this file from the profile loader, then call:
        Register-ProfileFunctions -FunctionsDir $FunctionsDir

.PARAMETER FunctionsDir
    Directory containing *.ps1 function files (typically ~/.config/powershell/functions).

.NOTES
    Safe to call once per session. Re-running refreshes stubs for files that
    have not been loaded yet.
#>

function Register-ProfileFunctions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FunctionsDir
    )

    if (-not (Test-Path -LiteralPath $FunctionsDir)) {
        return
    }

    if (-not $global:__PSProfileFunctions) {
        $global:__PSProfileFunctions = @{
            LoadedFiles   = @{}
            FileFunctions = @{}
        }
    }

    # Loader used by stubs — must stay global so first-call stubs can reach it.
    $global:__PSProfileFunctions.LoadFile = {
        param([Parameter(Mandatory)][string]$Path)

        if ($global:__PSProfileFunctions.LoadedFiles[$Path]) {
            return
        }

        foreach ($fn in @($global:__PSProfileFunctions.FileFunctions[$Path])) {
            Remove-Item -Path "Function:global:$fn" -Force -ErrorAction SilentlyContinue
        }

        $moduleName = 'PSProfile.Fn.' + [System.IO.Path]::GetFileNameWithoutExtension($Path)
        Remove-Module -Name $moduleName -Force -ErrorAction SilentlyContinue

        $escaped = $Path.Replace("'", "''")
        $moduleBody = [scriptblock]::Create(". '$escaped'`nExport-ModuleMember -Function * -Alias *")
        $mod = New-Module -Name $moduleName -ScriptBlock $moduleBody
        Import-Module -ModuleInfo $mod -Global -Force -DisableNameChecking | Out-Null

        $global:__PSProfileFunctions.LoadedFiles[$Path] = $true
    }

    function Test-IsNestedInFunction {
        param($Node)
        $p = $Node.Parent
        while ($null -ne $p) {
            if ($p -is [System.Management.Automation.Language.FunctionDefinitionAst]) {
                return $true
            }
            $p = $p.Parent
        }
        return $false
    }

    function Get-ProfileFileExports {
        param([string]$LiteralPath)

        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $LiteralPath,
            [ref]$tokens,
            [ref]$errors
        )

        if ($errors -and $errors.Count -gt 0) {
            return $null
        }

        $functions = [System.Collections.Generic.List[string]]::new()
        foreach ($fn in $ast.FindAll({
                    $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst]
                }, $true)) {
            if (Test-IsNestedInFunction $fn) { continue }
            [void]$functions.Add($fn.Name)
        }

        $aliases = [ordered]@{}
        foreach ($cmd in $ast.FindAll({
                    $args[0] -is [System.Management.Automation.Language.CommandAst]
                }, $true)) {
            if (Test-IsNestedInFunction $cmd) { continue }

            $cmdName = $cmd.GetCommandName()
            if ($cmdName -notin @('Set-Alias', 'New-Alias')) { continue }

            $aliasName = $null
            $aliasValue = $null
            $positionals = [System.Collections.Generic.List[string]]::new()
            $elements = @($cmd.CommandElements)

            for ($i = 1; $i -lt $elements.Count; $i++) {
                $el = $elements[$i]
                if ($el -is [System.Management.Automation.Language.CommandParameterAst]) {
                    $param = $el.ParameterName
                    $argText = $null
                    if ($null -ne $el.Argument) {
                        try { $argText = $el.Argument.SafeGetValue() } catch { $argText = $null }
                    }
                    elseif (($i + 1) -lt $elements.Count -and
                        $elements[$i + 1] -isnot [System.Management.Automation.Language.CommandParameterAst]) {
                        $i++
                        try { $argText = $elements[$i].SafeGetValue() } catch { $argText = $null }
                    }

                    if ($param -match '^(Name|n)$') {
                        $aliasName = $argText
                    }
                    elseif ($param -match '^(Value|v)$') {
                        $aliasValue = $argText
                    }
                }
                else {
                    try {
                        [void]$positionals.Add([string]$el.SafeGetValue())
                    }
                    catch { }
                }
            }

            if (-not $aliasName -and $positionals.Count -ge 1) { $aliasName = $positionals[0] }
            if (-not $aliasValue -and $positionals.Count -ge 2) { $aliasValue = $positionals[1] }

            if ($aliasName -and $aliasValue) {
                $aliases[$aliasName] = $aliasValue
            }
        }

        [pscustomobject]@{
            Functions = @($functions)
            Aliases   = $aliases
        }
    }

    function New-ProfileFunctionStub {
        param(
            [string]$FunctionName,
            [string]$LiteralPath
        )

        $escapedName = $FunctionName.Replace("'", "''")
        $escapedPath = $LiteralPath.Replace("'", "''")

        # No param() block: named args (-Force, -D, -WhatIf) must land in $args
        # so they can be re-splatted onto the real advanced function after load.
        Set-Item -Path "Function:global:$FunctionName" -Value ([scriptblock]::Create(@"
`$__psProfileCallArgs = `$args
& `$global:__PSProfileFunctions.LoadFile -Path '$escapedPath'
& '$escapedName' @__psProfileCallArgs
"@))
    }

    # Per-file export cache: parsing every file's AST costs ~50 ms per startup.
    $cachePath = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'PowerShellSetup/cache/function-exports.json'
    $cache = $null
    try {
        if ([System.IO.File]::Exists($cachePath)) {
            $cache = [System.IO.File]::ReadAllText($cachePath) | ConvertFrom-Json -AsHashtable
        }
    }
    catch { $cache = $null }
    if ($cache -isnot [hashtable]) { $cache = @{} }
    $cacheDirty = $false
    $liveFiles = [System.Collections.Generic.HashSet[string]]::new()

    foreach ($file in [System.IO.DirectoryInfo]::new($FunctionsDir).EnumerateFiles('*.ps1')) {
        $path = $file.FullName
        [void]$liveFiles.Add($path)
        $stamp = "$($file.Length)|$($file.LastWriteTimeUtc.Ticks)"
        $entry = $cache[$path]
        if ($entry -is [hashtable] -and $entry.stamp -ceq $stamp) {
            $exports = [pscustomobject]@{ Functions = @($entry.functions); Aliases = $entry.aliases }
        }
        else {
            $exports = Get-ProfileFileExports -LiteralPath $path
            if ($null -ne $exports) {
                $cache[$path] = @{ stamp = $stamp; functions = @($exports.Functions); aliases = $exports.Aliases }
                $cacheDirty = $true
            }
        }

        if ($null -eq $exports) {
            Write-Warning "Profile function file parse failed, skipping: $($file.Name)"
            continue
        }

        # Side-effect-only files (no functions): load immediately.
        if (-not $exports.Functions -or $exports.Functions.Count -eq 0) {
            try {
                . $path
            }
            catch {
                Write-Warning "Function file $($file.Name) failed: $_"
            }
            continue
        }

        # Already imported this session — leave the real commands alone.
        if ($global:__PSProfileFunctions.LoadedFiles[$path]) {
            continue
        }

        $global:__PSProfileFunctions.FileFunctions[$path] = @($exports.Functions)

        foreach ($fn in $exports.Functions) {
            New-ProfileFunctionStub -FunctionName $fn -LiteralPath $path
        }

        # Aliases exist before first load so `rsb` works without priming.
        foreach ($aliasName in $exports.Aliases.Keys) {
            $target = $exports.Aliases[$aliasName]
            Set-Alias -Name $aliasName -Value $target -Scope Global -Force -ErrorAction SilentlyContinue
        }
    }

    foreach ($stalePath in @($cache.Keys | Where-Object { -not $liveFiles.Contains($_) })) {
        $cache.Remove($stalePath)
        $cacheDirty = $true
    }
    if ($cacheDirty) {
        $tmp = "$cachePath.$PID.tmp"
        try {
            [void][System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($cachePath))
            [System.IO.File]::WriteAllText($tmp, ($cache | ConvertTo-Json -Depth 4 -Compress))
            [System.IO.File]::Move($tmp, $cachePath, $true)
        }
        catch {
            # The cache is an optimisation only.
            Remove-Item -LiteralPath $tmp -Force -ErrorAction Ignore
        }
    }
}
