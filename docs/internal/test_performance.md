# Unit Test Performance Analysis

This document explains why unit tests in cloud_controller_ng take a long time to load and proposes solutions.

## The Problem

Running a single unit test like `bundle exec rspec spec/unit/actions/app_create_spec.rb` takes approximately 20 seconds to load and only ~1.7 seconds to actually run. The load time dominates total test time.

## Root Causes

### 1. Eager Loading of the Entire Application (~1400 Ruby files)

The `spec_helper.rb` requires `cloud_controller.rb` which triggers a cascade of requires:

- `cloud_controller.rb` loads ~120 files directly from `lib/`
- `cloud_controller/controllers.rb` loads all 117 controller files via `Dir[]`
- `models.rb` loads 162 model files
- `services.rb` loads service-related code
- All 105 support files in `spec/support/` are loaded via `Dir[]`

This eager loading happens on every test run, even for a single spec file.

### 2. No Bootsnap Caching

[Bootsnap](https://github.com/shopify/bootsnap) is a library that caches `require` calls (both the file path resolution and the compiled instruction sequences). It can reduce boot time by 50-70% for large Ruby applications.

This project does not use bootsnap.

### 3. Spring Not Properly Configured

Spring and spring-commands-rspec are in the Gemfile, but Spring is not configured:

- No `config/spring.rb` file exists to specify what to watch
- Spring doesn't know which directories to preload
- Without configuration, Spring may not preload the application effectively

The bin/rspec attempts to use Spring, but without proper configuration, it may not be helping.

### 4. Spork is Outdated and Ineffective

The spec_helper.rb contains code to support Spork, but:

- Spork is loaded from an old git ref and is no longer maintained
- The implementation checks if spork is running via `ps | grep spork` which adds overhead
- Spork has been superseded by Spring

### 5. Database Setup on Every Run

`SpecBootstrap.init` is called on every test run with:

- `recreate_test_tables: true` (default) - recreates database tables
- `do_schema_migration: true` (default) - runs migration checks

These database operations add to startup time.

## Solutions

### Solution 1: Add Bootsnap (Recommended - Low Risk)

Bootsnap can be added with minimal changes and provides significant speedup.

**Implementation:**

1. Add bootsnap to Gemfile:

```ruby
group :development, :test do
  gem 'bootsnap', require: false
end
```

2. Add to `config/boot.rb` before other requires:

```ruby
require 'bootsnap/setup' if ENV.fetch('DISABLE_BOOTSNAP', nil).nil?
```

**Expected benefit:** 30-50% reduction in boot time with no risk to test behavior.

### Solution 2: Properly Configure Spring (Recommended - Medium Risk)

Create a proper Spring configuration so the preloader works effectively.

**Implementation:**

1. Create `config/spring.rb`:

```ruby
Spring.application_root = File.expand_path('..', __dir__)

Spring.watch(
  '.ruby-version',
  'Gemfile',
  'Gemfile.lock'
)

# Watch the lib directory for changes
%w[lib app spec/support].each do |path|
  Spring.watch path
end
```

2. Regenerate binstubs:

```bash
bundle exec spring binstub rspec
```

3. Verify Spring is running:

```bash
bin/spring status
```

**Expected benefit:** After first run, subsequent runs should complete in 1-3 seconds.

### Solution 3: Remove Spork (Cleanup - Low Risk)

Remove the outdated Spork code from spec_helper.rb to simplify the codebase.

**Implementation:**

Remove lines 5-13 and 225-239 from spec_helper.rb that deal with Spork, keeping only the `init_block.call` and `each_run_block.call` lines.

### Solution 4: Skip Database Migration Checks

Use the `NO_DB_MIGRATION=true` environment variable:

```bash
NO_DB_MIGRATION=true bundle exec rspec spec/unit/actions/app_create_spec.rb
```

This skips migration checks when the schema is known to be up-to-date.

**Expected benefit:** Saves 1-2 seconds per run.

## Recommended Approach

1. **First**: Add bootsnap (lowest risk, immediate benefit)
2. **Second**: Configure Spring properly (requires testing, but greatest benefit for iterative development)
3. **Third**: Remove Spork code (cleanup)
4. **Optional**: Use NO_DB_MIGRATION when appropriate

## Verification

After implementing changes, measure improvement with:

```bash
time bundle exec rspec spec/unit/actions/app_create_spec.rb --format progress
```

Compare the total time before and after each change.

## Measured Results

Baseline (no bootsnap, no Spring):
- Files took 28.45 seconds to load
- Total time: ~31 seconds

With bootsnap (cache populated):
- Files took 19-20 seconds to load
- Total time: ~22 seconds
- **Improvement: ~30% reduction in load time**

With Spring preloader (after first run):
- Total time: ~2 seconds
- **Improvement: ~93% reduction in total time**

The combination of bootsnap (for faster cold starts) and Spring (for iterative development) provides the best overall experience.
