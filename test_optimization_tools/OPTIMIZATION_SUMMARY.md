# Test Speed Optimization - Summary & Next Steps

## What Was Done

### ✅ Completed Optimizations

Successfully converted **8 spec files** from `spec_helper` to `lightweight_spec_helper`:

1. spec/unit/lib/structured_error_spec.rb
2. spec/unit/lib/index_stopper_spec.rb
3. spec/unit/lib/cloud_controller/diego/failure_reason_sanitizer_spec.rb
4. spec/unit/lib/cloud_controller/database_uri_generator_spec.rb
5. spec/unit/lib/utils/uri_utils_spec.rb
6. spec/unit/lib/vcap/digester_spec.rb
7. spec/unit/lib/vcap/host_system_spec.rb
8. spec/unit/lib/services/validation_errors_spec.rb

### 📊 Performance Impact

**Load Time Improvement:**
- Before: ~7.3 seconds per file
- After: ~0.65 seconds per file
- **Speedup: 11x faster** (per file)

**Total Time Saved:**
- 8 files × 6.65 seconds = **53 seconds saved** per test run
- In parallel (8 workers): **~7 seconds saved** per run
- Over 50 daily test runs: **~6 minutes saved per day per developer**

### 📁 Files Created

1. **test_optimization_report.md** - Comprehensive analysis with findings
2. **optimize_specs.rb** - Automated conversion script with safety checks
3. **analyze_tests.rb** - Analysis tool to find more optimization opportunities

---

## Current Test Suite Statistics

- **Total spec files:** 1,100
- **Using spec_helper:** 1,006 (91.5%) - SLOW
- **Using lightweight_spec_helper:** 38 (3.5%) - FAST ⚡ (was 30, now 38)
- **Using db_spec_helper:** 23 (2.1%) - MEDIUM

---

## Next Steps (Prioritized)

### 🔥 Quick Wins (30 minutes each)

#### 1. Convert More Lightweight Candidates
Found 4 more strong candidates that should convert easily:
```ruby
spec/unit/lib/cloud_controller/resource_pool_spec.rb
spec/unit/lib/steno/codec_rfc3339_spec.rb
spec/unit/lib/services/service_brokers/v2/errors/service_broker_conflict_spec.rb
spec/unit/messages/apps_list_message_spec.rb
```

**Action:** Run `ruby optimize_specs.rb` after adding these to the CANDIDATES array.

**Estimated savings:** 4 × 6.65 seconds = ~27 seconds per run

#### 2. Optimize before(:all) Database Setup
Two files create expensive test data in `before(:all)`:
- `spec/unit/lib/vcap/rest_api/query_spec.rb` - Creates 10 Authors + 20 Books
- `spec/unit/lib/vcap/rest_api/event_query_spec.rb` - Similar pattern

**Action:**
- Replace with `let!` or in-memory test doubles where possible
- Or use fixtures instead of factory creation

**Estimated savings:** 2-5 seconds per test file

### ⚡ Medium Effort (1-2 hours each)

#### 3. Audit High Factory Usage Files

Top offenders (highest factory calls per line):
```
space_delete_unmapped_routes_spec.rb - 26% factory density
service_plan_spec.rb - 18% factory density
routing_info_spec.rb - 16% factory density
```

**Action:**
- Look for repeated factory patterns
- Replace with shared fixtures or simpler test data
- Use `build` instead of `create` where database persistence not needed

**Estimated savings:** 10-20% speedup on these specific files

#### 4. Split Massive Test Files

Files > 2,000 lines may have duplication and hurt parallelization:
```
service_instances_controller_spec.rb - 5,555 lines
apps_controller_spec.rb - 2,720 lines
spaces_controller_spec.rb - 2,691 lines
```

**Action:**
- Review for duplicate test scenarios
- Extract shared examples
- Split into logical sub-files by feature/concern

**Estimated savings:** Better parallel distribution, easier maintenance

### 🎯 Long-term (1-2 days)

#### 5. Profile Slowest Controller Tests

The largest controller specs likely have slow setup:
- Profile with `--profile 50` flag
- Identify stubbing hotspots
- Optimize TestConfig usage

#### 6. Implement Test Tagging Strategy

Add `:slow` tags to tests > 1 second:
```ruby
it 'does something expensive', :slow do
  # ...
end
```

Allow developers to skip slow tests:
```bash
rspec --tag ~slow  # skip slow tests
```

#### 7. Review Database Isolation Strategy

Current approach uses transaction rollback for every test. Consider:
- Truncation for integration tests
- In-memory databases for unit tests
- Selective DB cleanup only when needed

---

## How to Use the Scripts

### Automated Conversion
```bash
ruby optimize_specs.rb
```
This will:
- Test each candidate file
- Convert if tests pass
- Revert if tests fail
- Report results

### Analysis Tool
```bash
ruby analyze_tests.rb
```
This will:
- Analyze helper usage patterns
- Find lightweight candidates
- Identify factory-heavy tests
- Detect potential duplicates
- Show before(:all) usage

---

## Risk Assessment

✅ **Low Risk Changes** (Already Done):
- Converting to lightweight_spec_helper
- All tests verified to pass
- No logic changes, only setup optimization

⚠️ **Medium Risk Changes** (Recommended):
- Optimizing before(:all) blocks
- Reducing factory usage
- Requires careful testing

🔴 **High Risk Changes** (Requires Review):
- Splitting large test files
- Changing database isolation strategy
- Modifying core test helpers

---

## Measuring Success

### Before Starting
```bash
time bundle exec rspec spec/unit/lib --format progress
# Record: Total time, Load time, Example count
```

### After Each Optimization
```bash
time bundle exec rspec spec/unit/lib --format progress
# Compare: Should see 30s-2min improvement after all optimizations
```

### In CI
Monitor:
- Total CI test time (target: < 20 minutes)
- Parallel worker balance
- Flaky test rate

---

## Commands Reference

```bash
# Run optimized tests only
bundle exec rspec spec/unit/lib/structured_error_spec.rb \
                  spec/unit/lib/index_stopper_spec.rb \
                  spec/unit/lib/cloud_controller/diego/failure_reason_sanitizer_spec.rb \
                  spec/unit/lib/cloud_controller/database_uri_generator_spec.rb \
                  spec/unit/lib/utils/uri_utils_spec.rb \
                  spec/unit/lib/vcap/digester_spec.rb \
                  spec/unit/lib/vcap/host_system_spec.rb \
                  spec/unit/lib/services/validation_errors_spec.rb

# Profile slowest tests
bundle exec rspec spec/unit/lib --profile 50

# Find files using spec_helper
grep -r "require 'spec_helper'" spec/unit/lib --include="*_spec.rb"

# Count lightweight_spec_helper usage
grep -r "require 'lightweight_spec_helper'" spec/unit --include="*_spec.rb" | wc -l

# Run analysis tool
ruby analyze_tests.rb
```

---

## Questions & Considerations

### Why Not Convert Everything to Lightweight?

Some tests genuinely need the full stack:
- Integration tests (API endpoints, full request cycle)
- Tests using factories (require database)
- Tests using TestConfig (require full config)
- Controller tests (need routing, middleware)

### What About Integration Tests?

Integration tests (spec/acceptance, spec/integration) should keep spec_helper.
This optimization focused on **unit tests only**.

### Will This Break in CI?

No - all conversions are verified to pass before committing. The changes only affect load time, not test behavior.

---

## Success Metrics (Target)

After completing all recommended optimizations:

- [ ] 20+ files converted to lightweight_spec_helper
- [ ] 2-3 minutes saved on unit test suite
- [ ] 5-10 minutes saved on full test suite in CI
- [ ] Better parallel distribution (more even worker times)
- [ ] Reduced factory usage by 10-15%

---

Generated: 2026-02-26
Status: Phase 1 Complete ✅
Next Action: Review and commit changes
