# uv workflow helpers for Astra Python development

uvdev() (
  unset UV_NO_SOURCES UV_LOCKED UV_FROZEN
  uv lock --upgrade && uv sync --dev
)

uvci() (
  export UV_NO_SOURCES=1
  unset UV_LOCKED UV_FROZEN
  uv lock --no-sources --upgrade &&
  export UV_LOCKED=1 &&
  uv sync --dev --locked --no-sources
)

uvtst() (
  unset UV_LOCKED UV_FROZEN UV_NO_SOURCES
  uv run ruff format . &&
  uv run ruff check . &&
  uv run ty check &&
  uv run pytest &&
  uv run deptry .
)
