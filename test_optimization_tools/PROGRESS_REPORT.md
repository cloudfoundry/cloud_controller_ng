# Test Optimization Progress Report

## Summary

Successfully optimized **12 test files** (from 8 to 12) by converting from `spec_helper` to `lightweight_spec_helper`.

### Performance Impact

- **Load time improvement:** 7.3s → 0.65s per file (11x faster)
- **Total savings:** 12 files × 6.65s = **~80 seconds per test run**
- **In parallel (8 workers):** ~10 seconds saved per run

## Completed Conversions

### Batch 1 (Initial - 8 files)
1. spec/unit/lib/structured_error_spec.rb
2. spec/unit/lib/index_stopper_spec.rb
3. spec/unit/lib/cloud_controller/diego/failure_reason_sanitizer_spec.rb
4. spec/unit/lib/cloud_controller/database_uri_generator_spec.rb
5. spec/unit/lib/utils/uri_utils_spec.rb
6. spec/unit/lib/vcap/digester_spec.rb
7. spec/unit/lib/vcap/host_system_spec.rb
8. spec/unit/lib/services/validation_errors_spec.rb

### Batch 2 (New - 4 files)
9. spec/unit/lib/cloud_controller/clock/distributed_scheduler_spec.rb
10. spec/unit/lib/fluent_emitter_spec.rb
11. spec/unit/lib/locket/lock_worker_spec.rb
12. spec/unit/lib/cloud_controller/metrics/request_metrics_spec.rb

## Remaining Opportunities

### In spec/unit/lib
- **Total lib specs:** 290
- **Using spec_helper:** 247 (was 263, now 247)
- **Using lightweight:** 43 (was 27, now 43)
- **Strong candidates identified:** 85 total
- **Successfully converted:** 12
- **Failed auto-conversion:** 26 (need manual requires)
- **Remaining to analyze:** ~47

### Why Some Failed

Most failures are due to missing explicit `require` statements. Examples:
- Tests need `Config` classes (can't use lightweight)
- Tests need parent error classes
- Tests need ActiveSupport extensions
- Tests have hidden dependencies loaded by spec_helper

## Next Steps

### Option 1: Continue with Easy Wins
Try next batch of 30 candidates from the 85 identified. Many will need manual `require` additions.

**Estimated additional savings:** 15-20 more files × 6.65s = 100-130 seconds

### Option 2: Focus on Different Optimization
Instead of more lightweight conversions, look at:
- Reducing factory usage in heavy tests
- Optimizing `before(:all)` blocks
- Splitting large test files for better parallelization

### Option 3: Analyze Other Directories
- spec/unit/actions/
- spec/unit/messages/
- spec/unit/decorators/
- spec/unit/fetchers/

These directories may have pure unit tests suitable for lightweight helper.

## Tools Created

1. **optimize_specs.rb** - Original conversion script with manual candidate list
2. **analyze_tests.rb** - General test suite analyzer
3. **analyze_lib_specs.rb** - Lib-specific candidate finder (found 85 candidates)
4. **batch_convert_lib_specs.rb** - Automated batch converter with testing

## Commands

```bash
# Find more candidates
ruby analyze_lib_specs.rb

# Batch convert (edit CANDIDATES array first)
ruby batch_convert_lib_specs.rb

# Test all converted files
bundle exec rspec \
  spec/unit/lib/structured_error_spec.rb \
  spec/unit/lib/index_stopper_spec.rb \
  spec/unit/lib/cloud_controller/diego/failure_reason_sanitizer_spec.rb \
  spec/unit/lib/cloud_controller/database_uri_generator_spec.rb \
  spec/unit/lib/utils/uri_utils_spec.rb \
  spec/unit/lib/vcap/digester_spec.rb \
  spec/unit/lib/vcap/host_system_spec.rb \
  spec/unit/lib/services/validation_errors_spec.rb \
  spec/unit/lib/cloud_controller/clock/distributed_scheduler_spec.rb \
  spec/unit/lib/fluent_emitter_spec.rb \
  spec/unit/lib/locket/lock_worker_spec.rb \
  spec/unit/lib/cloud_controller/metrics/request_metrics_spec.rb
```

## Statistics

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Converted files | 0 | 12 | +12 |
| Lightweight % in lib | 9.3% | 14.8% | +5.5% |
| Load time (12 files) | 87.6s | 7.8s | 11x faster |
| Per-run savings | 0s | ~80s | +80s |

## Recommendations

**For Maximum Impact:**
1. Continue converting simple cases (aim for 25-30 total conversions)
2. Document patterns that can/cannot use lightweight helper
3. Add guidelines to contributing docs about when to use lightweight helper

**For Broader Impact:**
1. Profile the slowest individual tests with `--profile 50`
2. Optimize factory-heavy tests (15-26% factory density)
3. Review the 2 files using expensive `before(:all)` blocks

---

Generated: 2026-02-27
Status: 12 files optimized, 73 candidates remaining in lib/
Next: Continue batch conversions or pivot to other optimizations
