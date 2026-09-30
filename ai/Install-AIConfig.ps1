<#
.SYNOPSIS
    Renders or installs the shared AI configuration using uv-managed Python.
.DESCRIPTION
    Default renders to ai/generated without changing live clients. -Install merges
    preferences and managed MCP definitions, with private backups. CLI binaries,
    plugins and authentication are separate setup steps.
.EXAMPLE
    ./ai/Install-AIConfig.ps1 -Install -EnableMcp github,playwright
#>
#requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('claude', 'codex', 'grok', 'opencode')]
    [string[]]$Clients = @('claude', 'codex', 'grok', 'opencode'),
    [switch]$Install,
    [string[]]$EnableMcp = @(),
    [string[]]$DisableMcp = @(),
    [string]$OutputDir,
    [string]$HomeDir
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) { throw 'Install uv first; it manages Python for this setup.' }
$setupArgs = @('run', '--no-project', '--python', '3.14', (Join-Path $PSScriptRoot 'setup.py'), '--clients') + $Clients
if ($Install) { $setupArgs += '--install' }
if ($EnableMcp.Count) { $setupArgs += @('--enable') + $EnableMcp }
if ($DisableMcp.Count) { $setupArgs += @('--disable') + $DisableMcp }
if ($OutputDir) { $setupArgs += @('--output', $OutputDir) }
if ($HomeDir) { $setupArgs += @('--home', $HomeDir) }
& uv @setupArgs
if ($LASTEXITCODE -ne 0) { throw "AI config setup failed (exit $LASTEXITCODE)." }
