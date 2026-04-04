# AGENTS.md

## Project Overview

This repository is a scaffolded workspace for **nanobot-ai**, a Python-based AI bot platform with Telegram integration and OpenRouter (LLM) API access. Source code has not yet been added.

**Tech stack:** Python 3.13, pip, venv, systemd (deployment), Dev Containers (Ubuntu).

## Build / Lint / Test Commands

_No source code exists yet. Commands below are placeholders to update once code is added._

```bash
# Install dependencies
pip install -e .

# Lint
ruff check .
ruff format --check .

# Type check
mypy .

# Run all tests
pytest

# Run a single test
pytest tests/test_file.py::test_function -v

# Run tests matching a keyword
pytest -k "keyword" -v
```

Update this section when `pyproject.toml`, `Makefile`, or other build configs are added.

## Code Style

### Language & Formatting
- Python 3.13+ only
- Use `ruff` for linting and formatting (4-space indent, 88-char line limit)
- Use type hints on all function signatures and class attributes
- Follow PEP 8 naming: `snake_case` for functions/variables, `PascalCase` for classes, `UPPER_SNAKE_CASE` for constants

### Imports
- Standard library imports first, then third-party, then local (grouped with blank lines between)
- Use absolute imports over relative imports
- One import per line; no wildcard imports (`from x import *`)

### Error Handling
- Use specific exception types; never bare `except:`
- Prefer custom exception classes for domain-specific errors
- Log errors with context before raising or re-raising
- Use context managers (`with` statements) for resource cleanup

### Testing
- Use `pytest` with `assert` statements (no `unittest.TestCase` style)
- Test file naming: `test_<module>.py` alongside or under `tests/`
- Use fixtures for shared setup; parametrize for multiple inputs
- Aim for meaningful test names: `test_<function>_<scenario>_<expected>`

### Git Conventions
- Small, focused commits with descriptive messages
- Never commit `.env` or secrets (enforced by `.gitignore`)
- Branch naming: `feature/<name>`, `fix/<name>`, `chore/<name>`

## Project Structure (Planned)

```
nanobot-ai/
├── src/              # Main package source
├── tests/            # Test suite
├── pyproject.toml    # Build config, dependencies, tool settings
├── .env.sample       # Environment variable template
└── notes.md          # Server deployment instructions
```

## Deployment

The bot runs as a systemd user service (`nanobot-gateway.service`) on a Linux server.
See `notes.md` for full setup: Python 3.13 venv, `pip install nanobot-ai`, `nanobot onboard --wizard`.

## Environment Variables

Required (see `.env.sample`):
- `ssh-url` — remote server address
- `email` — bot email
- `openrouter_api` — LLM API key
- `telegram_bot_id` — Telegram bot username
- `telegram_bot_token` — Telegram bot auth token

## AI Agent Rules

- No existing Cursor rules (`.cursor/rules/`, `.cursorrules`) or Copilot instructions (`.github/copilot-instructions.md`) found.
- This file serves as the single source of truth for coding conventions in this repo.
- Update this file when new tools, conventions, or project structure is established.
