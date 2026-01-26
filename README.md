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

| Variable       | Description                          | Default                        |
| -------------- | ------------------------------------ | ------------------------------ |
| `API_TOKEN`    | Token for rate-api                   | (required)                     |
| `REDIS_URL`    | Redis connection URL                 | (required)                     |
| `RATE_API_URL` | Rate API endpoint                    | `http://rate-api:8080/pricing` |
| `LOG_LEVEL`    | Log level (DEBUG, INFO, WARN, ERROR) | `INFO`                         |

## Endpoints

### GET /health

Health check endpoint.

```bash
curl http://localhost:3000/health
```

### POST /pricing

Fetch pricing data (V1: Simple mutex lock). Results are cached for 5 minutes.

```bash
curl -X POST http://localhost:3000/pricing \
  -H "Content-Type: application/json" \
  -d '{"attributes": [{"period": "Summer", "hotel": "FloatingPointResort", "room": "SingletonRoom"}]}'
```

### POST /pricing/v2

Fetch pricing data (V2: Leader-follower pattern). Results are cached for 5 minutes.

```bash
curl -X POST http://localhost:3000/pricing/v2 \
  -H "Content-Type: application/json" \
  -d '{"attributes": [{"period": "Summer", "hotel": "FloatingPointResort", "room": "SingletonRoom"}]}'
```

### POST /pricing/v3 (RECOMMENDED)

Fetch pricing data (V3: Enhanced leader-follower with circuit breaker). Results are cached for 5 minutes.

```bash
curl -X POST http://localhost:3000/pricing/v3 \
  -H "Content-Type: application/json" \
  -d '{"attributes": [{"period": "Summer", "hotel": "FloatingPointResort", "room": "SingletonRoom"}]}'
```

### GET /metrics

Get service metrics (V3 only).

```bash
curl http://localhost:3000/metrics
```

## Implementation Comparison

This project includes three distributed locking implementations:

| Version | Pattern                      | Best For                         | Status        | Files                                                                                         |
| ------- | ---------------------------- | -------------------------------- | ------------- | --------------------------------------------------------------------------------------------- |
| **V1**  | Mutex lock + polling         | Learning/prototyping             | Basic         | redis_cache.rb, pricing_service.rb                                                            |
| **V2**  | Leader-follower + BRPOP      | Long operations (>10s)           | Advanced      | distributed_lock.rb, async_request.rb, leader_follower_cache.rb, pricing_service_v2.rb       |
| **V3**  | Enhanced leader-follower     | **Production (RECOMMENDED)**     | Production    | circuit_breaker.rb, leader_follower_cache_v2.rb, pricing_service_v3.rb                       |

### V3 Features (Recommended for Production)

- ✅ Circuit breaker (prevents cascade failures)
- ✅ Stale cache fallback (graceful degradation)
- ✅ Retry with exponential backoff
- ✅ User-friendly timeouts (15s instead of 55s)
- ✅ Built-in metrics and monitoring
- ✅ Production-ready error handling

See [V3_IMPLEMENTATION.md](V3_IMPLEMENTATION.md) for detailed documentation.

See [V1_VS_V2.md](V1_VS_V2.md) for detailed comparison.

### Testing Both Implementations

```bash
# Run comparison test
ruby test_comparison.rb both

# Test only V1
ruby test_comparison.rb v1

# Test only V2
ruby test_comparison.rb v2
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
