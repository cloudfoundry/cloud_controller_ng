# 16: Rate Limiting

Date: 2026-09-09

## Status

Proposed

## Context

CC implements [rate limits](https://docs.cloudfoundry.org/running/rate-limit-cloud-controller-api.html) for the CF API:
- a general fixed-window rate limiter for API requests
- a concurrent request rate limiter for API endpoints that involves synchronous calls to service brokers 

These rate limits are applied per user. Global nginx rate limits supported by capi-release are out of scope for this ADR.

Experiments have demonstrated that the current rate limiters are not sufficient to protect the CF API from abuse. With a typical fixed-window rate limiting of a few 10k requests per user per hour and 3 to 10 CC api VMs configured for production (e.g. 4 core/16G VM, 4 Puma workers with 10 threads each), a single user can consume the complete CF API processing capacity and cause a CF API outage.

## Decision

### Short-term
We will protect the complete CF API by a general concurrent request rate limiter including requests by admin users. The concurrent request rate limiter will be implemented as middleware in CCNG.

### Long-term

CF API rate limiting should be moved from CCNG (Ruby process) into a dedicated routing component implemented in golang that replaces nginx. The fixed-window rate limiter should be replaced by a token-bucket rate limiter which allows to steer the available processing capacity of the CC in a more fair way between the users.

## Consequences

### Short-term

A single user can't overload the CF API anymore by running more parallel requests than the CC api VMs can process. The CF API is protected up to ~2.2k req/s per CC VM (max 429 response rate).

### Long-term

The protection level can be substantially increased (we expect at least factor 2).

CCNG is offloaded by token decoding/validation and rate limiting middleware. We may be able to remove Redis/Valkey from CCNG which was introduced because of rate limiting.

capi-release gets rid on unmaintained nginx-upload-module and we don't introduce additional dependencies like OpenResty or njs module.

Downside is the implementation and testing effort but we also gain full control of the implementation.

## Alternatives Considered

### Concurrent Req Rate Limiter as CCNG Middleware

[ccng #5361](https://github.com/cloudfoundry/cloud_controller_ng/pull/5361)

The PR also improves the middleware order to increase throughput when rate limits are hit.

Pros:
- simple
- big improvement compared to no concurrency rate limiting

Cons:
- less protection compared to a rate limiter outside of CCNG (max 2.2k req/s per api VM)
- rate-limited requests consume CCNG resources

### Rate limiting in nginx using OpenResty

Evaluation based on a POC.

Pros:
- stands up to 3k req/s per api VM
- no Redis/Valkey needed for rate limiters
- nginx provides concurrency limiter and token-bucket limiter out of the box
- offloads CCNG (token decoding/validation and rate limiting)
- may also allow to replace the unmaintained nginx upload module

Cons:
- token decoding and validation implemented in Lua (little know-how and experience)
- OpenResty is a fat dependency (but seems well maintained)
- probably harder to maintain over time
- nginx token-bucket limiter doesn't support X-RateLimiter-* headers

### Rate limiting in nginx using njs

Evaluation based on a POC. njs = nginx javascript module

Pros:
- stands up nearly 3k req/s per api VM
- no Redis/Valkey needed for rate limiters
- nginx provides concurrency limiter and token-bucket limiter out of the box
- offloads CCNG (token decoding/validation and rate limiting)
- simpler implementation compared to OpenResty

Cons:
- implementation is bit tricky to work around the nginx phases supported by njs
- slighly less performant compared to OpenResty/Lua
- doesn't help with unmaintained nginx upload module
- nginx token-bucket limiter doesn't support X-RateLimiter-* headers

### Rate limiting in nginx using a golang server for token decoding

POC implementation started but then aborted.

Pros:
- no Redis/Valkey needed for rate limiters
- nginx provides concurrency limiter and token-bucket limiter out of the box
- token decoding/validation logic implemented in non-exotic language
- no Lua or JavaScript coding

Cons:
- implementation of concurrency rate limiting requires 2 calls
- performance worse than other nginx options (tested with token-bucket limiter only)
- doesn't help with unmaintained nginx upload module
- nginx token-bucket limiter doesn't support X-RateLimiter-* headers

### Rate limiting in nginx using token decoding module in C

POC implementation started but then aborted.

Pros:
- no Redis/Valkey needed for rate limiters
- nginx provides concurrency limiter and token-bucket limiter out of the box
- no Lua or JavaScript coding, no nginx hacks

Cons:
- complex implementation in C, no/little knowledge in CAPI team
- doesn't help with unmaintained nginx upload module
- nginx token-bucket limiter doesn't support X-RateLimiter-* headers

### Replacing nginx by a CAPI specific go implementation

No POC yet. Idea is to replace nginx by a CAPI specific router implementation in golang.
A new capi router has to implement routing rules, mTLS, rate limiting and file upload.

Pros
- CAPI specific implementation without hacks
- implementation in a well-understood and performant language (no Lua or JavaScript)
- should perform better than nginx because of in-process token decoding and validation (to be validated)
- no Redis/Valkey needed for rate limiters
- offloads CCNG (token decoding/validation and rate limiting)
- no dependency to nginx and nginx modules, removes unmaintained nginx upload module

Cons
- implementation and testing effort
- risk involved in exchanging a critical component

## Measurements

For some implementation options we run throughput measurements based on a POC implementation. 

Test setup:
- bbl environment based on cf-deployment v58.2 with 2 CC api VMs (capi-release 1.239.0)
- CC api configuration
  - 4 cores, 16 G RAM
  - 4 Puma workers, 10 threads per worker
- load generation
  - vegeta on external VM
  - 300s attack time
  - all requests by a single user
  - assumed an API response time of ~106ms (i.e. a rather slow endpoint), simulated by adding a 100ms delay to the /v3/info endpoint
- rate limiting (per VM)
  - fixed-window rate limiter with very high limit so that it has no effect
  - concurrent request rate limiter with max 10 parallel requests per user

The max measured 200 response throughput for this test setup is ~189 req/s (= 56,700 200 responses in 300s).

The table shows the highest achievable attack request rate for which the CF API is still working stable:
- no 5xx responses
- achieves at least 90% of the max 200 responses (~51k 200 responses in 300s, ~170 req/s).

| Implementation | Rate | Duration | 200s | 429s | 5xx |
|---|---|---|---|---|---|
| Baseline (1)    |600 req/s | 300s | 180,000 | 0 | 0 |
| CCNG middleware |4000 req/s | 300s | 52,140 | 1,147,873 | 0 |
| nginx njs       |4750 req/s| 300s | 51,771 | 1,373,232 | 0 |
| nginx OpenResty |5250 req/s| 300s | 53,143 | 1,521,858 | 0 |

(1) Baseline = current implementation w/o concurrent request rate limiter.

Additional measurement of max rate limiting throughput, i.e. all requests are rejected with 429. Concurrent request rate limiter set to 0:

| Implementation | Rate | Duration | 200s | 429s | 5xx |
|---|---|---|---|---|---|
| Baseline (2)    | 1050 req/s | 300s | - | 315,000 | 0 |
| CCNG middleware | 4500 req/s | 300s | - | 1,353,000 | 0 |
| nginx njs       | 5750 req/s | 300s | - | 1,725,001 | 0 |
| nginx OpenResty | 6000 req/s | 300s | - | 1,800,007 | 0 |

(2) Baseline uses fixed-window rate limit with limit 0 instead of concurrent request rate limiter

## Additional Information

The rate limiter protection performance (i.e. which max load can be responded with 429) can be further improved by caching tokens that have been validated and decoded. This applies to all implementation options.

Max nginx response rate is ~8..10k req/s per CC api VM (static response by nginx w/o token decoding and rate limiting). It might be possible to increase it further by tuning nginx configuration. This indicates that a CAPI specific and properly optimized rate limiting implementation outside of CCNG can provide a higher protection level than an implementation within CCNG.