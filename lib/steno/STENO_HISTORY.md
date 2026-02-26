# Steno Integration History

This directory contains the steno logging library, integrated from https://github.com/cloudfoundry/steno

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

## Integration Details

- **Source Repository**: https://github.com/cloudfoundry/steno (house-keeping branch)
- **Integration Method**: Git subtree with --squash
- **Integration Date**: February 25, 2026
- **Final Steno Commit**: 5b08405f9 "Remove unused rack-test dependency and add explicit stdlib requires"

## What Was Integrated

- All steno library code (~1,106 lines)
- Custom RFC3339 codec (previously in lib/steno_custom_codec_temp/)
- LICENSE file (Apache 2.0 - copied from original repository for attribution)
- Test suite (moved to spec/unit/lib/steno/)

## What Was Excluded

- Gem infrastructure (gemspec, Gemfile, Rakefile)
- CI configuration (.github/)
- Documentation (README, CHANGELOG, RELEASING)
- Development tools (bin/steno-prettify, .rubocop*, etc.)

## Modifications Made After Integration

The following changes were made to adapt steno for CCNG's needs:

### 1. JSON Library Migration (Yajl → Oj)
- **Rationale**: CCNG uses Oj throughout; consolidate on single JSON library
- **Files changed**:
  - `lib/steno/codec/json.rb`: Changed `Yajl::Encoder.encode` → `Oj.dump`
  - `lib/steno/json_prettifier.rb`: Changed `Yajl::Parser.parse` → `Oj.load`, exception handling
  - `lib/steno/codec/codec_rfc3339.rb`: Added `require 'oj'`
  - `lib/steno/sink/counter.rb`: Changed encoder to Oj
  - Test files updated to use `Oj.load` instead of `Yajl::Parser.parse`

### 2. Syslog Reopening Fix
- **Issue**: "syslog already open" error in tests due to removal of syslog-logger wrapper
- **Fix**: Modified `lib/steno/sink/syslog.rb` to close syslog before reopening
- **Added**: `Syslog.close if Syslog.opened?` before `Syslog.open()`

### 3. RuboCop Compliance
- **Variable naming**:
  - `ex` → `exception` (in logger.rb, tagged_logger.rb)
  - `io` → `io_obj` (in sink/io.rb to avoid shadowing IO class)
- **Code style**:
  - `sprintf` → string interpolation in json_prettifier.rb
  - Added rubocop disable comments where needed (e.g., `Lint/BinaryOperatorWithIdenticalOperands`)
  - Added empty class documentation comments
- **Dependencies**: Added `require 'active_support/core_ext/module/delegation'` where needed

### 4. Test Structure Updates
- **Moved**: Tests from lib/steno/spec/ to spec/unit/lib/steno/ (CCNG convention)
- **Isolation**: Removed global spec_helper requires, added explicit requires per test file
- **Structure**: Wrapped test describes in parent `RSpec.describe` blocks for proper namespacing

### 5. Windows Support Removal
- **Rationale**: CCNG only runs on Linux; removing unused platform-specific code
- **Removed**:
  - `lib/steno/sink/eventlog.rb` (Windows Event Log sink)
  - `spec/unit/lib/steno/unit/sink/eventlog_spec.rb` (Windows tests)
  - Windows conditionals from config.rb, syslog.rb, and test files
  - `WINDOWS` constant from sink/base.rb
- **Simplified**: Syslog sink no longer conditionally defined
