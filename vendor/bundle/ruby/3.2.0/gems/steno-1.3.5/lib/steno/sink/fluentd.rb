require 'fluent-logger'
#
# Steno sink implementation for Fluentd
#
#   See fluentd at http://fluentd.org/
#   and fluent-logger at https://github.com/fluent/fluent-logger-ruby
#
class Steno::Sink::Fluentd < Steno::Sink::Base
  # @param [Hash] opts Key :tag_prefix tag prefix of fluent logs (default: steno)
  #                    Key :host fluentd host (default: 127.0.0.1)
  #                    Key :port fluentd port (deafult: 24224)
  #                    Key :buffer_limit buffer limit of fluent-logger
  def initialize(opts = {})
    super

    @fluentd = Fluent::Logger::FluentLogger.new(opts[:tag_prefix] || 'steno',
                                                host: opts[:host] || '127.0.0.1',
                                                port: opts[:port] || 24_224,
                                                buffer_limit: opts[:buffer_limit] || Fluent::Logger::FluentLogger::BUFFER_LIMIT)
    @io_lock = Mutex.new
  end

  def add_record(record)
    @fluentd.post(record.source, record)
  end

  def flush
    nil
  end
end
