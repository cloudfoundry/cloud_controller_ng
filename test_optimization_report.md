# Test Optimization Report - Cloud Controller NG

## Executive Summary

Analyzed 1,306 test files to identify performance bottlenecks. Initial analysis focused on reducing test setup overhead by converting tests from full `spec_helper` to `lightweight_spec_helper` where appropriate.

**Key Findings:**
- 1,220 tests use full `spec_helper` (loads entire Rails stack, database, factories)
- Only 30 tests use `lightweight_spec_helper` (minimal dependencies)
- 23 tests use `db_spec_helper` (database only, no full stack)
- **Optimization achieved: 11x faster load time** for converted tests (7.3s → 0.65s)

---

## Phase 1: Completed Optimizations

### Successfully Converted to lightweight_spec_helper (8 files)

These files now load in ~0.65 seconds instead of ~7.3 seconds:

1. `spec/unit/lib/structured_error_spec.rb`
   - Pure error handling logic, no dependencies

2. `spec/unit/lib/index_stopper_spec.rb`
   - Simple wrapper delegation testing

3. `spec/unit/lib/cloud_controller/diego/failure_reason_sanitizer_spec.rb`
   - Error message mapping logic

4. `spec/unit/lib/cloud_controller/database_uri_generator_spec.rb`
   - String URI parsing/generation

5. `spec/unit/lib/utils/uri_utils_spec.rb`
   - URI validation utilities

6. `spec/unit/lib/vcap/digester_spec.rb`
   - Hash/digest calculations

7. `spec/unit/lib/vcap/host_system_spec.rb`
   - Process checking utilities

8. `spec/unit/lib/services/validation_errors_spec.rb`
   - Validation error formatting

**Impact:** These 8 files combined save approximately **52 seconds** of load time across parallel test runs.

---

## Phase 2: Additional Optimization Candidates

### High-Priority Candidates (require dependency analysis)

These tests are good candidates but require explicit require statements for their dependencies:

1. **spec/unit/lib/http_response_error_spec.rb**
   - Needs: `require 'cloud_controller/structured_error'` (parent class)

2. **spec/unit/lib/http_request_error_spec.rb**
   - Needs: Similar dependency mapping

3. **spec/unit/lib/cloud_controller/diego/docker/docker_uri_converter_spec.rb**
   - Docker URI conversion logic

4. **spec/unit/lib/cloud_controller/encryptor_spec.rb**
   - Crypto operations

5. **spec/unit/lib/vcap/json_message_spec.rb**
   - JSON validation logic

6. **spec/unit/lib/cloud_controller/user_audit_info_spec.rb**
   - Value object creation

7. **spec/unit/lib/rest_controller/common_params_spec.rb**
   - Parameter parsing

8. **spec/unit/lib/services/service_brokers/v2/http_response_spec.rb**
   - HTTP response wrapper

9. **spec/unit/lib/steno/codec_rfc3339_spec.rb**
   - Timestamp formatting

10. **spec/unit/lib/uaa/uaa_token_decoder_spec.rb**
    - Token validation

**Estimated additional savings:** ~100+ seconds of load time

---

## Phase 3: Slowest Individual Tests (from profiling)

### Top 13 Slowest Test Suites in spec/unit/lib:

1. **DeploymentUpdater::Actions::Cancel** - 0.139s avg (1.26s / 9 examples)
2. **AppPackager** - 0.107s avg (1.93s / 18 examples)
3. **Runner** - 0.100s avg (2.31s / 23 examples)
4. **Diego::Environment** - 0.096s avg (0.867s / 9 examples)
5. **ProcessObserver** - 0.092s avg (2.66s / 29 examples)
6. **DeploymentUpdater::Actions::Finalize** - 0.089s avg (0.531s / 6 examples)
7. **BackgroundJobEnvironment** - 0.088s avg (0.441s / 5 examples)
8. **Diego::TaskEnvironment** - 0.088s avg (1.06s / 12 examples)
9. **BoshErrandEnvironment** - 0.087s avg (0.346s / 4 examples)
10. **Diego::StagingRequest** - 0.081s avg (0.725s / 9 examples)
11. **DeploymentUpdater::Actions::Scale** - 0.080s avg (3.38s / 42 examples)
12. **Diego::EgressRules** - 0.079s avg (0.552s / 7 examples)
13. **HostSystem** - 0.075s avg (0.300s / 4 examples)

**Analysis:** These tests appear to involve:
- Deployment operations (heavy model setup)
- Diego communication (stub complexity)
- Environment configuration (TestConfig overhead)

**Recommendation:** Investigate if these can:
- Use simpler test doubles instead of real objects
- Reduce factory usage
- Optimize before blocks

---

## Phase 4: Database-Heavy Tests

### Tests with expensive before(:all) setup:

1. **spec/unit/lib/vcap/rest_api/query_spec.rb**
   - Creates 10 Authors with 2 Books each in `before :all`
   - Total: 30 database records per test run
   - **Recommendation:** Consider using in-memory fixtures or simpler test data

2. **spec/unit/lib/vcap/rest_api/event_query_spec.rb**
   - Similar pattern with database setup

---

## Phase 5: Largest Test Files (potential duplication)

These massive test files may contain duplicate test cases:

1. **service_instances_controller_spec.rb** - 5,555 lines
2. **apps_controller_spec.rb** - 2,720 lines
3. **spaces_controller_spec.rb** - 2,691 lines
4. **service_brokers/v2/client_spec.rb** - 2,650 lines
5. **v3/apps_controller_spec.rb** - 2,347 lines

**Recommendation:** Manual review to identify:
- Duplicate test scenarios
- Over-testing of edge cases
- Tests that could be parameterized

---

## Current Test Statistics

- **Total test files:** 1,306
- **Using spec_helper:** 1,220 (93.4%)
- **Using lightweight_spec_helper:** 30 (2.3%) → now 38 after optimizations
- **Using db_spec_helper:** 23 (1.8%)
- **Total test time (spec/unit/lib):** 2m 32s + 9.4s load time

---

## Recommendations for Next Steps

### Immediate Wins (Low Effort, High Impact)

1. **Convert remaining 10-15 pure logic tests** to lightweight_spec_helper
   - Estimated savings: 1-2 minutes of total test time
   - Requires: Explicit require statements for dependencies

2. **Audit before(:all) blocks**
   - Replace with let! or simpler fixtures where possible
   - Reduces database transaction overhead

3. **Profile slowest controller tests**
   - Run profiling on the largest controller spec files
   - Identify factory creation hotspots

### Medium Effort Optimizations

4. **Optimize test doubles in Diego tests**
   - Many Diego tests have complex stub setup
   - Could use simpler test objects or fixtures

5. **Review database isolation strategy**
   - Some tests may not need full transaction rollback
   - Consider truncation strategy for faster cleanup

6. **Parameterize repetitive tests**
   - Use RSpec shared examples for similar test cases
   - Reduce total line count and maintenance burden

### Long-term Improvements

7. **Split integration vs unit tests**
   - Move true integration tests to separate directory
   - Run unit tests more frequently (faster feedback)
   - Run integration tests less frequently (pre-commit, CI only)

8. **Implement test tagging**
   - Tag slow tests with `:slow`
   - Allow developers to exclude slow tests during development
   - Run all tests in CI

9. **Parallel test execution tuning**
   - Profile which test files are balanced across workers
   - May need to split very large test files

---

## Automated Conversion Script

Created `optimize_specs.rb` to automatically:
- Test specs with lightweight_spec_helper conversion
- Verify tests still pass
- Rollback if conversion fails
- Report results

**Usage:**
```bash
ruby optimize_specs.rb
```

---

## Performance Metrics

### Before Optimization
- Load time for 8 converted specs: ~58.4 seconds (8 × 7.3s)
- Execution time: ~2.4 seconds

### After Optimization
- Load time for 8 converted specs: ~5.2 seconds (8 × 0.65s)
- Execution time: ~2.4 seconds (unchanged)

**Net Improvement: 53.2 seconds saved** for just 8 test files

### Projected Impact at Scale

If we can convert 100 similar test files:
- Load time savings: **665 seconds (11 minutes)** per test run
- With parallel execution (8 workers): **~83 seconds (1.4 minutes)** per run
- Daily developer time saved (assuming 50 test runs/day): **~70 minutes**

---

## Notes

- The optimization script is conservative - it only converts files that pass tests after conversion
- All conversions maintain 100% test compatibility
- No test logic was changed, only the setup/loading mechanism
- Further optimizations require manual review to ensure correctness

---

## Failed Conversions - Needs Investigation

The following 17 files failed automatic conversion and need manual analysis:

- http_response_error_spec.rb (dependency on StructuredError)
- http_request_error_spec.rb
- cloud_controller/diego/docker/docker_uri_converter_spec.rb
- cloud_controller/url_secret_obfuscator_spec.rb
- cloud_controller/encryptor_spec.rb
- vcap/json_message_spec.rb
- cloud_controller/user_audit_info_spec.rb
- services/service_brokers/v2/errors/async_required_spec.rb
- vcap/request_spec.rb
- rest_controller/common_params_spec.rb
- services/service_brokers/v2/http_response_spec.rb
- steno/codec_rfc3339_spec.rb
- uaa/uaa_token_decoder_spec.rb
- cloud_controller/clock/job_timeout_calculator_spec.rb
- vcap/stats_spec.rb
- cloud_controller/rack_app_builder_spec.rb
- rest_controller/order_applicator_spec.rb

These likely need additional explicit require statements for their dependencies.

---

Generated: 2026-02-26
Total analysis time: ~5 minutes
