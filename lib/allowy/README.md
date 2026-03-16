# Allowy (Internalized Copy)

This directory contains an internalized copy of the archived allowy authorization library:
https://github.com/dnagir/allowy

**License:** MIT License
**Copyright:** (c) 2014 Dmytrii Nagirniak
**Inlined version:** 2.1.0
**Source commit:** `5d2c6f09a9617a2ad097a3b11ecabb32d48ff80b` (2015-01-06)
**Upstream status:** Archived (last commit: 2015-01-06)

The upstream LICENSE file is included in this directory.

## Why Inlined

- The upstream repository was archived with no updates since 2015
- Removes external gem dependency
- CCNG only uses a subset of allowy functionality (AccessControl, Context, Registry)

## Changes from Upstream

**Files included:** `access_control.rb`, `context.rb`, `registry.rb` (with RuboCop fixes applied)

**Files skipped (not used by CCNG):**
- `controller_extensions.rb` - Rails helper_method integration
- `matchers.rb` and `rspec.rb` - RSpec `be_able_to` matcher (CCNG uses its own `allow_op_on_object`)
- `version.rb` - version constant

## Usage in CCNG

Allowy is used **only by the V2 API** for authorization. This code can be removed together with the V2 API removal.

Note: If `/v2/info` endpoint is kept after V2 removal, `InfoController` should be refactored to not extend `RestController::BaseController` first.

The V3 API uses a different authorization system (`VCAP::CloudController::Permissions`).

## Tests

```bash
bundle exec rspec spec/unit/lib/allowy/
```
