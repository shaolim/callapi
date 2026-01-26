# Pricing API Service

A Ruby service that provides cached access to a dynamic pricing model with multiple concurrency strategies.

## Problem Statement

At Tripla, we use a dynamic pricing model for hotel rooms. The model's inference process is computationally expensive, but calculated rates remain valid for up to 5 minutes. This service acts as an efficient intermediary that:

- Caches pricing data for 5 minutes
- Handles concurrent requests without duplicate API calls
- Respects rate limits (10,000+ requests/day with single token)
- Provides graceful degradation when the upstream API fails

## Quick Start

```bash
# Set your API token
export API_TOKEN=your_token_here

# Start all services
docker compose up --build --watch
```

The service will be available at `http://localhost:3000`.

## API Endpoints

| Endpoint | Description |
| -------- | ----------- |
| `GET /health` | Health check |
| `POST /pricing` | V1: Simple mutex lock |
| `POST /pricing/v2` | V2: Leader-follower pattern |
| `POST /pricing/v3` | V3: Circuit breaker + fallback |

### Example Request

```bash
curl -X POST http://localhost:3000/pricing/v3 \
  -H "Content-Type: application/json" \
  -d '{
    "attributes": [
      {"period": "Summer", "hotel": "FloatingPointResort", "room": "SingletonRoom"}
    ]
  }'
```

### Example Response

```json
[
  {
    "period": "Summer",
    "hotel": "FloatingPointResort",
    "room": "SingletonRoom",
    "price": 150.00
  }
]
```

## API Versions Comparison

| Feature | V1 | V2 | V3 |
| ------- | -- | -- | -- |
| Caching | Yes | Yes | Yes |
| Prevents duplicate API calls | Yes | Yes | Yes |
| Efficient waiting (no polling) | No | Yes | Yes |
| Handles long API responses | No | Yes | Yes |
| Circuit breaker | No | No | Yes |
| Stale cache fallback | No | No | Yes |
| Retry with backoff | No | No | Yes |

**Recommendation:** Use `/pricing/v3` for production deployments.

For detailed technical comparison, see [design.md](design.md).

## Architecture

```
                                    +-------------+
                                    |  rate-api   |
                                    | (upstream)  |
                                    +------^------+
                                           |
+--------+     +-------------------+       |       +-------+
| Client | --> | Pricing Service   | ------+-----> | Redis |
+--------+     | (V1/V2/V3)        |               | Cache |
               +-------------------+               +-------+
```

### V3 Architecture (Recommended)

```
Request
   |
   v
Check Cache -----> [Hit] --> Return cached data
   |
   v [Miss]
Check Circuit Breaker
   |
   +----> [Open] --> Return stale cache or empty
   |
   v [Closed]
Acquire Lock
   |
   +----> [Leader] --> Call API --> Cache --> Notify followers
   |
   +----> [Follower] --> Wait (BRPOP) --> Receive result
```

## Installation

### Requirements

- Ruby 3.2+
- Redis 7+
- Docker (recommended)

### With Docker Compose (Recommended)

```bash
# Clone and navigate to project
cd callapi

# Set environment variable
export API_TOKEN=your_token_here

# Start services with hot reload
docker compose up --build --watch
```

### Without Docker

1. Install dependencies:

```bash
bundle install
```

1. Start Redis and rate-api:

```bash
docker run -d -p 6379:6379 redis:7-alpine
docker run -d -p 8080:8080 tripladev/rate-api:latest
```

1. Create `.env` file:

```bash
API_TOKEN=your_token_here
REDIS_URL=redis://localhost:6379
RATE_API_URL=http://localhost:8080/pricing
```

1. Run the server:

```bash
bundle exec ruby -rdotenv/load main.rb
```

## Configuration

| Variable | Description | Default |
| -------- | ----------- | ------- |
| `API_TOKEN` | Token for rate-api authentication | (required) |
| `REDIS_URL` | Redis connection URL | (required) |
| `RATE_API_URL` | Rate API endpoint | `http://rate-api:8080/pricing` |
| `LOG_LEVEL` | Log level (DEBUG, INFO, WARN, ERROR) | `INFO` |

## Project Structure

```
callapi/
├── main.rb                    # Application entry point and HTTP handlers
├── pricing_service.rb         # V1: Basic pricing service
├── pricing_service_v2.rb      # V2: Leader-follower pricing service
├── pricing_service_v3.rb      # V3: Enhanced with circuit breaker
├── redis_cache.rb             # V1: Simple mutex-based cache
├── leader_follower_cache.rb   # V2: BRPOP-based coordination
├── leader_follower_cache_v2.rb# V3: With circuit breaker + fallback
├── distributed_lock.rb        # Auto-extending distributed lock
├── async_request.rb           # Follower wait mechanism
├── circuit_breaker.rb         # Circuit breaker pattern
├── design.md                  # Technical design document
├── Dockerfile
└── docker-compose.yml
```

## Development

### Run Linter

```bash
bundle exec rubocop
```

### Auto-fix Linting Issues

```bash
bundle exec rubocop -a
```

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f development
docker compose logs -f rate-api
```

## Technical Documentation

For detailed technical design decisions, architecture comparisons, and known issues, see:

- [Technical Design Document](design.md) - Comprehensive comparison of V1, V2, V3 approaches
