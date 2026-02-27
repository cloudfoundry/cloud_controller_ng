# Test Optimization Tools

This directory contains helper scripts and documentation for analyzing and optimizing the test suite.

## Scripts

### Analysis Tools
- `analyze_tests.rb` - General test suite analyzer
- `analyze_lib_specs.rb` - Lib-specific candidate finder
- `analyze_other_dirs.rb` - Analyzes other spec/unit directories

### Conversion Tools
- `optimize_specs.rb` - Manual batch converter with candidate list
- `batch_convert_lib_specs.rb` - Automated batch converter for lib specs
- `smart_convert_specs.rb` - Smart converter that adds required dependencies
- `test_multi_dir.rb` - Multi-directory batch tester
- `test_more_messages.rb` - Message-specific batch tester
- `test_presenters.rb` - Presenter-specific batch tester
- `test_tiny_batch.rb` - Small batch tester
- `test_utilities.rb` - Utility file batch tester
- `find_simple_tests.rb` - Finds truly standalone tests

## Documentation
- `FINAL_SUMMARY.md` - Complete summary of all optimizations
- `OPTIMIZATION_SUMMARY.md` - Quick reference guide
- `SESSION_SUMMARY.md` - Detailed session notes
- `PROGRESS_REPORT.md` - Progress tracking
- `test_optimization_report.md` - Detailed analysis report

## Usage

```bash
# Find candidates
ruby test_optimization_tools/analyze_tests.rb
ruby test_optimization_tools/analyze_lib_specs.rb
ruby test_optimization_tools/analyze_other_dirs.rb

# Convert files
ruby test_optimization_tools/optimize_specs.rb
ruby test_optimization_tools/batch_convert_lib_specs.rb
```

## Note

These scripts are excluded from RuboCop checks and should be removed before the final PR.
To remove: `git rm -r test_optimization_tools/`
