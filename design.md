# Pricing Service Technical Design Document

## Overview

This document compares three different approaches for handling concurrent pricing API requests with caching and coordination.

**Problem Statement:**

- Multiple concurrent requests may need the same pricing data
- The upstream rate-api is expensive (slow) and has rate limits
- We need to avoid duplicate API calls while ensuring all requests get data
- The rate-api returns intermittent 500 errors

---

## Architecture Comparison

### V1: Simple Mutex Lock + Polling (`/pricing`)

**Components:**

- `PricingService` → `RedisCache`

**Flow:**

```
Request → Check Cache → [Miss] → Try Acquire Lock
                                      ↓
                        [Got Lock] → Call API → Cache Result → Release Lock
                                      ↓
                        [No Lock]  → Poll Cache (100ms intervals, max 5s) → Return Result
                                      ↓
                                   [Timeout] → Call API directly
```

**Implementation Details:**

| Aspect               | Detail                         |
| -------------------- | ------------------------------ |
| Lock mechanism       | `SETNX` with 10s TTL           |
| Waiting strategy     | Polling every 100ms            |
| Max wait time        | 5 seconds (50 retries × 100ms) |
| Lock ownership       | Not tracked (unsafe release)   |
| Retry on API failure | None                           |
| Fallback             | None                           |

**Code Location:** `redis_cache.rb`

---

### V2: Leader-Follower with BRPOP (`/pricing/v2`)

**Components:**

- `PricingServiceV2` → `LeaderFollowerCache` → `DistributedLock` + `AsyncRequest`

**Flow:**

```
Request → Check Cache → [Miss] → Try Acquire Lock (with auto-extend)
                                      ↓
                        [Leader]  → Call API → Cache Result → Publish to Followers
                                      ↓
                        [Follower] → Register in waiters list → BRPOP (block until result)
```

**Implementation Details:**

| Aspect               | Detail                                      |
| -------------------- | ------------------------------------------- |
| Lock mechanism       | `SETNX` with 60s TTL + auto-extend every 2s |
| Waiting strategy     | `BRPOP` (Redis blocking pop)                |
| Max wait time        | 55 seconds                                  |
| Lock ownership       | UUID tracked                                |
| Retry on API failure | None                                        |
| Fallback             | None                                        |

**Key Innovation:**

- Uses Redis pub/sub pattern via lists
- Leader pushes result to each follower's unique queue
- Followers block efficiently with `BRPOP` (no polling)
- Lock auto-extends for long-running operations

**Code Location:** `leader_follower_cache.rb`, `distributed_lock.rb`, `async_request.rb`

---

### V3: Enhanced Leader-Follower with Circuit Breaker (`/pricing/v3`)

**Components:**

- `PricingServiceV3` → `LeaderFollowerCacheV2` → `DistributedLock` + `AsyncRequest` + `CircuitBreaker`

**Flow:**

```
Request → Check Cache → [Hit] → Return
              ↓
           [Miss] → Check Circuit Breaker
                          ↓
              [Open] → Return Stale Cache or Empty
                          ↓
              [Closed/Half-Open] → Try Acquire Lock
                                        ↓
                          [Leader]  → Call API (with 30s timeout)
                                        → Success: Cache + Publish
                                        → Failure: Record in Circuit Breaker
                                        ↓
                          [Follower] → BRPOP with retry (max 2 retries, exponential backoff)
                                        → Timeout: Return Stale Cache
```

**Implementation Details:**

| Aspect               | Detail                                      |
| -------------------- | ------------------------------------------- |
| Lock mechanism       | `SETNX` with 60s TTL + auto-extend every 2s |
| Waiting strategy     | `BRPOP` with exponential backoff retry      |
| Max wait time        | 15 seconds (user-friendly)                  |
| Lock ownership       | UUID tracked                                |
| Retry on API failure | Via circuit breaker half-open state         |
| Fallback             | Stale cache (15 min TTL) or empty array     |
| Circuit breaker      | Opens after 5 failures, 60s timeout         |

**Key Innovations:**

- Circuit breaker prevents cascade failures
- Stale cache provides graceful degradation
- Shorter follower timeout (15s vs 55s) for better UX
- Exponential backoff on follower retries
- API timeout protection (30s)

**Code Location:** `leader_follower_cache_v2.rb`, `circuit_breaker.rb`

---

## Comparison Matrix

| Feature                  | V1                        | V2                      | V3                        |
| ------------------------ | ------------------------- | ----------------------- | ------------------------- |
| **Wait Efficiency**      | Poor (polling)            | Good (BRPOP)            | Good (BRPOP)              |
| **Long Operations**      | Limited (10s lock)        | Supported (auto-extend) | Supported (auto-extend)   |
| **Thundering Herd**      | Partial (on timeout)      | Prevented               | Prevented                 |
| **API Failure Handling** | None                      | None                    | Circuit breaker           |
| **Graceful Degradation** | None                      | None                    | Stale cache fallback      |
| **User Experience**      | Poor (5s wait, then fail) | Moderate (55s wait)     | Good (15s wait, fallback) |
| **Complexity**           | Low                       | Medium                  | High                      |
| **Resource Usage**       | High (polling)            | Low (blocking)          | Low (blocking)            |

---

## Known Issues

### V1 Issues

1. **Race condition in lock release** - Does not verify ownership before deleting lock
2. **Thundering herd on timeout** - All timed-out requests hit API simultaneously
3. **No retry logic** - Fails immediately on API errors
4. **Inefficient polling** - Wastes CPU and Redis connections

### V2 Issues

1. **No fallback** - Fails if API is down
2. **Long timeout** - 55s wait may be too long for users
3. **No protection against repeated failures** - Keeps trying failing API

### V3 Issues

1. **Complexity** - More components to maintain and debug
2. **Stale data** - May return outdated pricing in failure scenarios

---

## Recommendation

### Best Approach: V3 (Enhanced Leader-Follower with Circuit Breaker)

**Reasons:**

1. **Production-Ready Reliability**
   - Circuit breaker prevents cascade failures when rate-api is unhealthy
   - Stale cache ensures users always get some response
   - Handles the intermittent 500 errors gracefully

2. **Optimal User Experience**
   - 15-second timeout is reasonable for users
   - Exponential backoff reduces unnecessary retries
   - Always returns data (fresh, stale, or empty) rather than errors

3. **Resource Efficiency**
   - BRPOP eliminates polling overhead
   - Circuit breaker reduces load on failing services
   - Only one request hits the API (leader), others wait efficiently

4. **Operational Safety**
   - Safe lock release with ownership verification
   - Auto-extending locks support variable API response times
   - Comprehensive logging for debugging

**When to Use Each Version:**

| Version | Use Case                                                      |
| ------- | ------------------------------------------------------------- |
| V1      | Simple applications, fast APIs (<1s), low concurrency         |
| V2      | Medium complexity, reliable APIs, acceptable long waits       |
| V3      | Production systems, unreliable APIs, user-facing applications |

---

## Future Improvements

1. **Add retry logic to V1** - Simple exponential backoff for API calls
2. **Metrics and monitoring** - Track cache hit rates, API latency, circuit breaker state
3. **Distributed circuit breaker** - Share state across instances via Redis
4. **Request coalescing** - Batch multiple concurrent requests into single API call
5. **Cache warming** - Proactively refresh popular cache keys before expiration
