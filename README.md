# Steno
Steno is a lightweight, modular logging library written specifically to support
Cloud Foundry.

## Concepts

Steno is composed of three main classes: loggers, sinks, and formatters. Loggers
are the main entry point for Steno. They consume user input, create structured
records, and forward said records to the configured sinks. Sinks are the
ultimate destination for log records. They transform a structured record into
a string via a formatter and then typically write the transformed string to
another transport.

## Configuration

To use steno, you must configure one or more 'sinks', a 'codec' and a 'context'.
If you don't provide a codec, steno will encode your logs as JSON.

For example:

    config = Steno::Config.new(
      :sinks   => [Steno::Sink::IO.new(STDOUT)],
      :codec   => Steno::Codec::Json.new,
      :context => Steno::Context::ThreadLocal.new)

### from YAML file

Alternatively, Steno can read its configuration from a YAML file in the following format:

```yaml
# config.yml
---
logging:
  file: /some/path            # Optional - path a log file
  max_retries: 3              # Optional - number of times to retry if a file write fails.
  syslog: some_syslog.id      # Optional - only works on *nix systems
  eventlog: true              # Optional - only works on Windows
  fluentd:                    # Optional
    host: fluentd.host
    port: 9999
  level: debug                # Optional - Minimum log level that will be written.
                              # Defaults to 'info'
```
Then, in your code:
```ruby
config = Steno::Config.from_file("path/to/config.yml")
```

With this configuration method, if neither `file`, `syslog` or `fluentd` are provided,
steno will use its stdout as its sink. Also, note that the top-level field `logging` is required.

### from Hash

As a third option, steno can be configured using a hash with the same structure as the above
YAML file (without the top-level `logging` key):
```ruby
config = Steno::Config.from_hash(config_hash)
```

## Usage

    Steno.init(config)
    logger = Steno.logger("test")  
    logger.info("Hello world!")

### Log levels

    LEVEL	NUMERIC RANKING 
    off		0
    fatal	1
    error	5
    warn	10
    info	15
    debug	16
    debug1	17
    debug2	18
    all		30

