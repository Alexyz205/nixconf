---
name: python-devops
description: Python for DevOps - API clients, config parsing, CLI tools, async patterns, testing
license: MIT
compatibility: opencode
metadata:
  audience: developers
  workflow: python
---

# Purpose

Python patterns for DevOps tooling. CLI, API clients, config, async, testing.

## CLI with Typer

```python
import typer
from typing import Annotated

app = typer.Typer(help="DevOps tool")

@app.command()
def deploy(
    env: Annotated[str, typer.Argument(help="Target environment")],
    dry_run: Annotated[bool, typer.Option("--dry-run")] = False,
    verbose: Annotated[bool, typer.Option("--verbose", "-v")] = False,
):
    ...

if __name__ == "__main__":
    app()
```

- Always include `--dry-run`, `--verbose`, `--help`
- Return exit codes: `raise typer.Exit(code=1)`

## API Clients (httpx, not requests)

```python
import httpx
from tenacity import retry, stop_after_attempt, wait_exponential

@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, max=10))
async def get_resource(client: httpx.AsyncClient, url: str) -> dict:
    response = await client.get(url, timeout=30.0)
    response.raise_for_status()
    return response.json()
```

- `httpx` for async, HTTP/2, connection pooling
- Always set explicit timeouts
- Retry with tenacity (exponential backoff)
- Context managers for connection lifecycle

## Config (pydantic-settings)

```python
class Config(BaseSettings):
    model_config = {"env_prefix": "APP_", "env_file": ".env"}
    db_host: str
    db_port: int = 5432
    debug: bool = False
```

- Env vars > config files > defaults
- Validate at startup, fail fast

## Async Patterns

```python
async def process_batch(items, concurrency=10):
    semaphore = asyncio.Semaphore(concurrency)
    async def bounded(item):
        async with semaphore:
            return await process_item(item)
    return await asyncio.gather(*[bounded(i) for i in items])
```

- Semaphores to bound concurrency
- `asyncio.gather` for parallel I/O
- `TaskGroup` (3.11+) for structured concurrency
- `asyncio.to_thread()` for blocking calls

## Testing

```python
@pytest.fixture
def mock_client():
    client = AsyncMock(spec=httpx.AsyncClient)
    client.get.return_value = httpx.Response(200, json={"key": "value"})
    return client
```

- `pytest-asyncio` for async tests
- `respx` for httpx mocking
- `typer.testing.CliRunner` for CLI tests

## Project Layout

```text
src/my_tool/
├── __main__.py    # Entry point
├── cli.py         # Commands
├── client.py      # API client
├── config.py      # Settings
└── utils.py
```

- `pyproject.toml` (not setup.py)
- `src/` layout to prevent import confusion
- Use `uv` for deps + virtual envs

## When to Use

- DevOps CLI tools and automation
- API integration scripts
- Production readiness review
