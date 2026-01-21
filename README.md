# Pricing API

A simple Ruby API that fetches pricing data and caches responses in Redis.

## Requirements

- Ruby 3.2
- Redis
- Docker (optional)

## Setup

```bash
bundle install
```

## Running

### With Docker Compose

```bash
docker compose up --build --watch
```

### Without Docker

1. Start Redis and rate-api:
```bash
docker run -d -p 6379:6379 redis:7-alpine
docker run -d -p 8080:8080 tripladev/rate-api:latest
```

2. Run the server:
```bash
bundle exec ruby -rdotenv/load main.rb
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `API_TOKEN` | Token for rate-api | (required) |
| `REDIS_URL` | Redis connection URL | (required) |
| `RATE_API_URL` | Rate API endpoint | `http://rate-api:8080/pricing` |
| `LOG_LEVEL` | Log level (DEBUG, INFO, WARN, ERROR) | `INFO` |

## Endpoints

### GET /health

Health check endpoint.

```bash
curl http://localhost:3000/health
```

### POST /pricing

Fetch pricing data. Results are cached for 5 minutes.

```bash
curl -X POST http://localhost:3000/pricing \
  -H "Content-Type: application/json" \
  -d '{"attributes": [{"period": "Summer", "hotel": "FloatingPointResort", "room": "SingletonRoom"}]}'
```

## Development

Run linter:
```bash
bundle exec rubocop
```

Auto-fix:
```bash
bundle exec rubocop -a
```
