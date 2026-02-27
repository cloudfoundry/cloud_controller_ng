# Items Requiring Review/Permission

## High-Impact Optimizations Needing Permission

### 1. Factory Usage Reduction (HIGH IMPACT)

**Issue:** Some test files have 15-26% factory density, which is very high. Factory calls (`.make`, `.create`) are expensive because they:
- Hit the database
- Create full object graphs
- Run validations and callbacks

**Top offenders found:**
- space_delete_unmapped_routes_spec.rb - 26.1% (24 factories / 92 lines)
- service_plan_spec.rb - 18.0% (87 factories / 482 lines)
- routing_info_spec.rb - 15.9% (70 factories / 440 lines)

**Proposed optimization:**
- Replace `.create` with `.build` where persistence isn't needed
- Use simpler test doubles instead of full factory objects
- Share factory objects across related tests
- Use `let!` instead of creating in each example

**Permission needed:**
- This changes test setup patterns, not logic
- May affect test readability
- Should I proceed with optimizing factory-heavy files?

### 2. Expensive before(:all) Optimization (MEDIUM IMPACT)

**Files identified:**
- spec/unit/lib/vcap/rest_api/query_spec.rb
- spec/unit/lib/vcap/rest_api/event_query_spec.rb

**Issue:** These create 30+ database records in `before(:all)` blocks

**Proposed optimization:**
- Move to `let!` or fixtures
- Use in-memory test data instead of database
- Consider extracting to shared examples

**Permission needed:**
- These are database query tests, so may legitimately need DB data
- Should I optimize these or are they intentionally integration-y?

### 3. Large File Splitting (LOW PRIORITY)

**Files over 2,000 lines:**
- service_instances_controller_spec.rb - 5,555 lines
- apps_controller_spec.rb - 2,720 lines
- spaces_controller_spec.rb - 2,691 lines

**Proposed:**
- Split into multiple files by feature/concern
- Extract shared examples
- Better for parallelization

**Permission needed:**
- This is a big refactoring
- Should I attempt this or is it too risky?

## Questions/Decisions Needed

### Q1: Lightweight Conversion Strategy
Many candidates failed because they need explicit `require` statements. Should I:
A. Manually add requires for each failed case (tedious but thorough)
B. Focus only on files that convert with simple substitution (what we've been doing)
C. Stop lightweight conversions and focus on other optimizations

**Recommendation:** Option C - we've hit diminishing returns on lightweight conversions

### Q2: CI Impact
You mentioned our optimizations don't show up in CI yet. This suggests:
- The 28 files we optimized aren't in CI's critical path
- There are much slower tests dominating CI time
- We need to profile actual CI runs

**Should I:**
- Focus on profiling to find CI bottlenecks?
- Continue with systematic optimizations?
- Both?

### Q3: db_spec_helper Candidates
Some tests might only need database, not full Rails stack. They could use `db_spec_helper` instead of `spec_helper`.

**Permission needed:**
- Should I explore this middle ground?
- Or stick with lightweight vs spec_helper only?

## Risk Assessment

### Low Risk (Can proceed without permission)
✅ Lightweight spec_helper conversions - we've been doing this successfully
✅ RuboCop fixes - automated and safe
✅ Documentation improvements

### Medium Risk (Documenting for review)
⚠️ Factory usage reduction - changes test patterns but not logic
⚠️ before(:all) optimization - might affect test isolation

### High Risk (Definitely need permission)
🔴 Large file splitting - big refactoring
🔴 Changing test logic or assertions
🔴 Removing tests (even if they look duplicate)

## Current Status

**Completed:**
- ✅ 28 files optimized with lightweight_spec_helper
- ✅ 186 seconds saved per run
- ✅ All changes committed locally

**In Progress:**
- 🔄 Analyzing factory usage patterns
- 🔄 Profiling slow tests
- 🔄 Looking for more optimization opportunities

**Blocked/Needs Permission:**
- ❓ Factory reduction in high-density files
- ❓ before(:all) optimization
- ❓ Direction for CI-focused optimizations

## Analysis Results

### Factory Usage Files
After examining `space_delete_unmapped_routes_spec.rb` (26% factory density):
- **Finding:** Factories are legitimately needed - tests database deletion logic
- **Recommendation:** This is not "excessive" factory usage, it's appropriate for the test
- **Action:** Mark as low priority optimization

### before(:all) Files
After examining `query_spec.rb`:
- **Finding:** Creates 10 Authors + 20 Books in before(:all)
- **Purpose:** Tests database query filtering against real DB
- **Issue:** This is an integration test, not a unit test
- **Recommendation:** These files might belong in integration/ directory instead
- **Action:** Needs architectural discussion - not a quick optimization

### Lightweight Conversion Status
After multiple attempts:
- **Success rate:** ~25% overall (28/109 attempted)
- **Best directory:** messages/ (13/15 = 87%)
- **Finding:** Hit diminishing returns - remaining candidates have hidden dependencies
- **Recommendation:** Stop lightweight conversions, focus elsewhere

---

Last Updated: [Autonomous work session - awaiting user return]
