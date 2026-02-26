# Steno Logging Library

This directory contains the Steno logging library, integrated into Cloud Controller NG from the original standalone repository.

**Original Repository**: https://github.com/cloudfoundry/steno
**Integration Date**: February 25, 2026
**Integration Method**: Git subtree (squashed)
**Final Upstream Commit**: 5b08405f9 "Remove unused rack-test dependency and add explicit stdlib requires"

## About This Integration

Steno was originally maintained as a separate gem used by Cloud Controller NG. It has been integrated directly into CCNG because:

1. **Low maintenance overhead**: Steno is stable and rarely changes
2. **Compliance requirements**: CCNG requires annual dependency updates; integrating removes this overhead for a stable library
3. **Single ownership**: Both projects are maintained by the Cloud Foundry Foundation

This is a **modified version** of the original Steno library, adapted for CCNG's specific needs.

## What Was Integrated

- All steno library code (~1,106 lines)
- Custom RFC3339 codec (previously in `lib/steno_custom_codec_temp/`)
- LICENSE file (Apache 2.0 - for attribution)
- NOTICE file (Apache 2.0 copyright notices)
- Test suite (in `spec/unit/lib/steno/`)

## What Was Excluded

- Gem infrastructure (gemspec, Gemfile, Rakefile)
- CI configuration (.github/)
- Documentation (README, CHANGELOG, RELEASING)
- Development tools (bin/steno-prettify, .rubocop*, etc.)

## Modifications Made After Integration

The following changes were made to adapt steno for CCNG. **When making future modifications to this integrated library, please document them in this section.**

### 1. JSON Library Migration (Yajl → Oj)
**Rationale**: Consolidate on single JSON library used throughout CCNG

**Changes**:
- `lib/steno/codec/json.rb`: `Yajl::Encoder.encode` → `Oj.dump`
- `lib/steno/codec/codec_rfc3339.rb`: Added `require 'oj'`
- `lib/steno/sink/counter.rb`: Changed to Oj, fixed to use string keys
- Test files updated to use `Oj.load`

### 2. Syslog Reopening Fix
**Issue**: "syslog already open" error in tests after removal of syslog-logger wrapper

**Fix**: Modified `lib/steno/sink/syslog.rb`:
```ruby
Syslog.close if Syslog.opened?
```

### 3. RuboCop Compliance
**Variable naming**:
- `ex` → `exception` (logger.rb, tagged_logger.rb)
- `io` → `io_obj` (sink/io.rb - avoid shadowing IO class)

**Code style**:
- `sprintf` → string interpolation
- Added rubocop disable comments where needed
- Added empty class documentation
- `Rails/Delegate` cop: Converted `def to_s; @name.to_s; end` to `delegate :to_s, to: :@name` in `log_level.rb`
  - Required adding `require 'active_support/core_ext/module/delegation'`

### 4. Test Structure Updates
- Moved tests from `lib/steno/spec/` to `spec/unit/lib/steno/` (CCNG convention)
- Removed global spec_helper requires, added explicit requires per test
- Wrapped test describes in parent `RSpec.describe` blocks

### 5. Windows Support Removal
**Rationale**: CCNG only runs on Linux

**Removed**:
- `lib/steno/sink/eventlog.rb` (Windows Event Log sink)
- `spec/unit/lib/steno/unit/sink/eventlog_spec.rb`
- Windows conditionals from config.rb, syslog.rb, test files
- `WINDOWS` constant from sink/base.rb

### 6. Unused Features Removal (Round 1)
**Rationale**: Remove dead code not used by CCNG

**Removed**:
- `lib/steno/version.rb` - Version constant no longer needed (not a gem)
- `lib/steno/json_prettifier.rb` - CLI tool for prettifying logs, unused (~110 lines)
- `lib/steno/core_ext.rb` - Monkey patches for `.logger` on Module/Class/Object, CCNG uses `Steno.logger()` instead (~50 lines)
- `spec/unit/lib/steno/unit/json_prettifier_spec.rb` - Tests for removed feature
- `spec/unit/lib/steno/unit/core_ext_spec.rb` - Tests for removed feature
- Removed `require 'steno/version'` from steno.rb

**What's kept** (even if unused):
- `TaggedLogger` - Part of public API via `Logger#tag()`
- `Logger#log_exception()` - Useful utility method
- `Context::FiberLocal` - Valid alternative context type, minimal code

### 7. Unused Features Removal (Round 2)
**Rationale**: Deeper analysis revealed more unused code

**Removed**:
- `lib/steno/sink/fluentd.rb` - Fluentd sink, never configured or used (~60 lines)
- `lib/steno/tagged_logger.rb` - TaggedLogger class, never used (~60 lines)
- `Logger#tag()` method - Never called in CCNG (4 lines)
- `Logger#log_exception()` method - Never called in CCNG (4 lines)
- `Steno::Context::FiberLocal` - Fiber context, only ThreadLocal is used (~15 lines)
- `Steno.set_logger_regexp()` - Dynamic logger level adjustment, unused (~20 lines)
- `Steno.clear_logger_regexp()` - Counterpart method, unused (~15 lines)
- `Steno.logger_level_snapshot()` - Logger level inspection, unused (~10 lines)
- Removed Fluentd config line from config.rb
- Removed `require 'steno/tagged_logger'` from steno.rb
- Removed `require 'steno/sink/fluentd'` from sink.rb
- Removed Fiber monkey patches from context.rb
- Test files for removed features

**Total code reduction**: ~240 lines (Round 1) + ~175 lines (Round 2) = **~415 lines removed**

**What's kept**:
- `Steno::Codec::Json` - Backward compatibility fallback for timestamp='deprecated'
- `Steno::Context::Null` - Default fallback context
- All log levels including debug1, debug2 - debug2 is actively used

---

## Making Future Modifications

If you modify this integrated steno library:

1. **Document changes** in the "Modifications Made After Integration" section above
2. **Include rationale** for why the change was made
3. **List affected files** and what changed
4. **Run tests** to ensure nothing breaks: `bundle exec rspec spec/unit/lib/steno/`
5. **Update this README** in the same commit as your changes

## Original Steno Commit History (102 commits)

The complete commit history from the steno repository:

```
5b08405 Remove unused rack-test dependency and add explicit stdlib requires
34ef84a Remove unmaintained syslog-logger dependency
bf4ac4e Add Ruby 3.4 support and update requirements
b257530 Fix RuboCop violations and improve code quality
57787dc Add release infrastructure and documentation
cb5a012 Bump version
86e2349 Merge pull request #13 from cloudfoundry/exhume
a5ad345 Exhume Steno
e2c9408 Fix nil pointer error when log_level set to :off
506c505 Streamline multi-copyright notice
0a827b7 Follow standard format for multi-copyright NOTICE
e7ea239 Add NOTICE
5a8a57f Use syslog logger instead of directly opening syslog
8ab2127 bump to ruby 2.2.4
e0e7bb5 Merge pull request #9 from julz/lovelylogs
e16cc96 Add human-readable date output
02d0630 Merge pull request #10 from julz/fixdeprecation
4de7686 Merge pull request #11 from julz/shouldacoulda
c3210b7 The class should equal, the should shouldn't class
98b6775 Fix deprecation warning
3117002 Bump to 1.2.4; add patch level to ruby-version.
b0a8d1f Merge pull request #8 from IronFoundry/master
9ba52a5 Respone to feedback for more flexible version identifier
51fe7cd Lock down version of win32-eventlog
aa5816a Update constants for eventlog from lastest gem changes.
d353f47 Merge pull request #7 from phanle/master
adb49fd Remove HttpHandler
6f3bc4a Merge pull request #6 from cloudfoundry/fix_truncate
d9b68f3 correctly truncate messages in syslog sink
3acd37c Trying to have different releases for windows and non-windows
4d58d56 Bump to 1.2.1
574733a bumped to version 1.2.0
a2afdcd Replace deprecated mock with double in specs
ad581ec Merge pull request #5 from IronFoundry/master
e9e4c0c Add code and tests to work on windows and unix.
c5269e8 Remove unsupported ruby version of build
cc9b5c5 Better way to symbolize hashes
d88c707 Record.new must take a Symbol for its log_level arg
619b634 Add counter sink
f7da4c0 Steno no longer keeps a count of how many logs are made for each log level
38c35b8 Steno keeps a count of how many logs are made for each log level
07fcd12 Merge pull request #4 from jbayer/master
3142e35 Use .ruby-version
bc20521 fixed spacing in README
a9a336e added included log level rankings to README
b5fa16e Improve configuration documentation
e24435d Merge pull request #3 from yssk22/request/fluentd-sink
41fdd93 Merge branch 'request/fluentd-sink' of https://github.com/yssk22/steno into request/fluentd-sink
efb16f0 add fluentd sink using fluent-logger.
5146e9f Removed call to error_format to match new grape api
c992224 add fluentd sink using fluent-logger.
8b47040 Add default rake task
fed9479 Update README.md
fb1af6f Bump patch version
9ebfed4 Add Travis configuration
60f6635 Allow data field to be nil for prettifier
5c68aa0 Line # in steno-prettify starts with 1, not 0.
1f55686 Ensure steno-prettify doesn't crash on bad input.
15000f0 Add missing test for retrying IO errors.
6ac2070 Styling fix.
2003285 Retry writes in IO sink during write error(s).
e323dbe Truncate syslog message.
98c3196 Merge "Prettify uses longest source name to size column"
882c0cd Prettify uses longest source name to size column
54b6221 Bump version number
69967d3 steno-prettify handles prefixes
9334fec Test that a record's timestamp uses UTC
2fedddc Bump patch-level
560cbdc Disable buffering for input to steno-prettify
6bf435f Bump patch
39dc91b Require yajl-ruby ~> 1.0
441a7fb This is a library: don't depend on Gemfile
f3fc952 Don't call git from gemspec
e71a658 Stringify log messages
ea0a294 Extend core_ext
4dc656d Merge "bin/steno-prettify allows non-json lines."
2ff9145 bin/steno-prettify allows non-json lines.
5798d9e Use correct license
b81279b Bump version
6058541 Fix syslog sink to use name to map to priority
c7f8b16 Add #flush to syslog sink
a2dbd72 Move spec files to match structure in lib/
8476bc5 Bump version.
029b123 Make Steno::Config#to_config_hash a public method.
49fd654 Steno can now create a config from a hash.
cdc5ee1 Exit cleanly on SIGINT
c74e349 Add ``alignment mode'' that omits data to provide aligned logs
daa7552 Trim filename to 2 levels
97b3f4b I'm a dummy, print the prettified output
281fe43 Add tool to convert json formatted logs into more human-friendly format
9afc1ee Steno::Config.from_file should look for the ``logging'' key
1bbaf6f User must require core_ext
9928a53 Initialize steno with an empty config upon require
ff2f6e6 Update README to include Bug filing info per Deepika
17c1dcc Add a method to Class that returns a logger named after the class
2a2c27e Add proxy logger class for persistent user data
069c2b5 Add spec/reports to .gitignore
5533060 Add file, lineno, and method to json codec
6fafe41 Source_id -> source
1e71f6f Use level_name instead of name
407d8f7 Ignore Gemfile.lock
a1a602a Initial commit of steno
```

## License

Steno is licensed under the Apache License 2.0. See LICENSE and NOTICE files in this directory for full copyright and license information.

**Copyright (c) 2015 - Present CloudFoundry.org Foundation, Inc. All Rights Reserved.**

This project contains software that is Copyright (c) 2012-2015 Pivotal Software, Inc.
