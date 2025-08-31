# OpenAI Mock Server

Mock, fast, OpenAI‑compatible API in Go. Ideal for development, demos, and tests. Includes built‑in docs, Glazed CLI integration, logging, streaming, and a configurable rule engine.

## Quickstart

1) Build and run
```bash
go build -o openai-mock-server ./cmd/openai-mock-server
./openai-mock-server --log-level info serve
```

2) Health check
```bash
curl -s http://localhost:3117/health | jq
```

3) Chat completions (cURL)
```bash
curl -s http://localhost:3117/v1/chat/completions -H 'Content-Type: application/json' -d '{
  "model": "gpt-3.5-turbo",
  "messages": [{"role": "user", "content": "Hello!"}]
}' | jq
```

## Documentation
- Getting started: `docs/GETTING_STARTED.md`
- Configuration: `docs/CONFIGURATION.md`
- Responses API: `docs/RESPONSES_API.md`
- Streaming guide: `docs/STREAMING.md`
- Agents notes: `docs/AGENTS.md`
- In‑app help: `./openai-mock-server help` or `GET /help`

## Examples and tests
- Examples: `examples/python/` and `examples/streaming/`
- Tests: `tests/python/`
- Install Python deps (optional):
```bash
pip install -r tests/python/requirements.txt
```

## Features
- OpenAI SDK compatible: `/v1/chat/completions`, `/v1/models`, `/v1/responses`
- Streaming via SSE for Chat and Responses API
- Configurable rule engine (tools, error injection, delays)
- Built‑in docs with Glazed HelpSystem
- Zerolog via Glazed logging flags (`--log-level`, `--log-format`, etc.)
- CORS enabled

## Config
Default config: `pkg/server/config/bot.yaml`. Override with `MOCK_SERVER_CONFIG=/path/to/bot.yaml`.

## License
MIT
