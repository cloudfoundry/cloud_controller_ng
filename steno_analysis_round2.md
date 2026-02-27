# Steno Feature Analysis - Round 2

## Summary
After removing obvious unused features, this is a deeper analysis of remaining code.

---

## ✅ CONFIRMED USED Features

### Core Logging
- `Steno.logger(name)` - Used 60+ times ✅
- `Steno.init()` - Used in initialization ✅
- `Steno::Logger` - Core class ✅
- `Steno::Record` - Log records ✅
- Log levels: fatal, error, warn, info, debug, **debug2** (used once) ✅

### Sinks
- `Steno::Sink::IO` - File and stdout logging ✅
- `Steno::Sink::Syslog` - Syslog integration ✅
- `Steno::Sink::Counter` - Log counting ✅

### Codecs
- `Steno::Codec::JsonRFC3339` - Primary codec ✅
- `Steno::Codec::Json` - Fallback when timestamp='deprecated' (config uses 'rfc3339') ⚠️

### Context
- `Steno::Context::ThreadLocal` - Explicitly used ✅
- `Steno::Context::Null` - Default fallback ✅

### Configuration
- `Steno::Config` - Configuration class ✅
- `Steno::Config.to_config_hash()` - Used ✅

---

## ❓ POTENTIALLY UNUSED Features

### 1. **Steno::Sink::Fluentd** ❌
**Status**: NOT used anywhere in CCNG
- Not in config files
- No code references outside steno library
- **Size**: ~60 lines
- **Recommendation**: ⚠️ **REMOVE** - unused sink, can be re-added if needed

### 2. **Steno::Codec::Json** (regular, non-RFC3339) ❓
**Status**: Only used as fallback for timestamp='deprecated'
- CCNG config uses 'rfc3339', not 'deprecated'
- Only triggered if `@config.dig(:format, :timestamp) == 'deprecated'`
- Never explicitly used in CCNG
- **Size**: ~50 lines
- **Recommendation**: ⚠️ **KEEP** - Backward compatibility fallback, small code

### 3. **Steno::Context::FiberLocal** ❌
**Status**: NOT used in CCNG
- Only ThreadLocal is explicitly used
- Part of Context module alongside Null and ThreadLocal
- **Size**: ~10 lines within context.rb
- **Recommendation**: ⚠️ **REMOVE** - Valid alternative but unused

### 4. **Steno::TaggedLogger** ❌
**Status**: NOT used in CCNG
- Accessible via `Logger#tag()` but never called
- No `.tag(` calls in CCNG codebase
- **Size**: ~60 lines
- **Recommendation**: ⚠️ **REMOVE** - Unused public API feature

### 5. **Logger#log_exception()** ❌
**Status**: NOT used in CCNG
- Convenience method for logging exceptions
- No calls to `.log_exception` in CCNG
- **Size**: 4 lines
- **Recommendation**: ⚠️ **REMOVE** - Trivial to add back if needed

### 6. **Steno.set_logger_regexp()** ❌
**Status**: NOT used in CCNG
- Dynamic logger level adjustment by regex
- **Size**: ~20 lines
- **Recommendation**: ⚠️ **REMOVE** - Advanced feature, unused

### 7. **Steno.clear_logger_regexp()** ❌
**Status**: NOT used in CCNG
- Counterpart to set_logger_regexp
- **Size**: ~15 lines
- **Recommendation**: ⚠️ **REMOVE** - Unused

### 8. **Steno.logger_level_snapshot()** ❌
**Status**: NOT used in CCNG
- Returns snapshot of logger levels
- **Size**: ~10 lines
- **Recommendation**: ⚠️ **REMOVE** - Unused

### 9. **Log Levels: :debug1, :all, :off** ❓
**Status**:
- `:debug2` IS used (1 occurrence in task_environment_variable_collector.rb)
- `:debug1` NOT used
- `:all` NOT used (likely a sentinel value)
- `:off` NOT explicitly used in CCNG, but tested in steno's own tests
- **Size**: Part of log_level.rb LEVELS hash
- **Recommendation**: ⚠️ **KEEP** - Part of level system, minimal overhead

---

## 📊 Removal Candidates Summary

| Feature | File | LOC | Used? | Recommendation |
|---------|------|-----|-------|----------------|
| Fluentd sink | sink/fluentd.rb | ~60 | ❌ No | ✅ **REMOVE** |
| TaggedLogger | tagged_logger.rb | ~60 | ❌ No | ✅ **REMOVE** |
| FiberLocal context | context.rb | ~10 | ❌ No | ✅ **REMOVE** |
| Logger regexp methods | steno.rb | ~45 | ❌ No | ✅ **REMOVE** |
| log_exception() | logger.rb | 4 | ❌ No | ✅ **REMOVE** |
| Codec::Json | codec/json.rb | ~50 | ⚠️ Fallback | ⚠️ KEEP (backward compat) |

---

## 💡 Recommendation

**Safe to Remove (Round 2):**
1. ✅ `lib/steno/sink/fluentd.rb` (~60 lines)
2. ✅ `lib/steno/tagged_logger.rb` (~60 lines)
3. ✅ `Steno::Context::FiberLocal` from context.rb (~10 lines)
4. ✅ `Steno.set_logger_regexp()` from steno.rb (~20 lines)
5. ✅ `Steno.clear_logger_regexp()` from steno.rb (~15 lines)
6. ✅ `Steno.logger_level_snapshot()` from steno.rb (~10 lines)
7. ✅ `Logger#log_exception()` from logger.rb (4 lines)
8. ✅ Remove `require 'steno/tagged_logger'` from steno.rb
9. ✅ Remove test files for above features

**Total savings**: ~175 lines

**Keep** (used or important fallback):
- Codec::Json (backward compatibility)
- Context::Null (default fallback)
- All log levels (debug2 is used, others part of system)

---

## Impact Analysis

### If we remove TaggedLogger:
- Need to remove `Logger#tag()` method (4 lines)
- No impact on CCNG - method never called

### If we remove FiberLocal:
- No impact - never used
- ThreadLocal and Null remain

### If we remove Fluentd:
- Remove from config.rb line 56
- Remove require from sink.rb
- No impact on CCNG

### If we remove logger regexp methods:
- Clean up ~45 lines from steno.rb
- Remove @logger_regexp and @logger_regexp_level instance variables
- No impact on CCNG

**Total potential code reduction**: ~175 lines (Round 2) + ~240 lines (Round 1) = **~415 lines total**
