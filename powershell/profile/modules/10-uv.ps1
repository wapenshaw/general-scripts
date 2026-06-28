<#
.SYNOPSIS
  uv (Python package manager) workflow helpers.
.DESCRIPTION
  Module 10 of the modular PowerShell profile. Mirrors zsh's uv.zsh.
  Depends on uv being installed (checked via Get-Command).
#>

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) { return }

function uvdev {
    <# .SYNOPSIS Lock + sync dev dependencies #>
    uv lock && uv sync --dev
}

function uvci {
    <# .SYNOPSIS CI-mode lock + sync (no dev extras) #>
    uv lock && uv sync
}

function uvtst {
    <# .SYNOPSIS Run ruff + ty + pytest + deptry gate #>
    uv run ruff check . && uv run ty check . && uv run pytest && uv run deptry .
}
