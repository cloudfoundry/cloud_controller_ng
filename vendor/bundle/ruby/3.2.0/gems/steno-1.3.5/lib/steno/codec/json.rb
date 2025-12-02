require 'yajl'

require 'steno/codec/base'

module Steno
  module Codec
  end
end

class Steno::Codec::Json < Steno::Codec::Base
  def initialize(opts = {})
    @iso8601_timestamps = opts[:iso8601_timestamps] || false
  end

  def encode_record(record)
    msg =
      if record.message.valid_encoding?
        record.message
      else
        # Treat the message as an arbitrary sequence of bytes.
        escape_nonprintable_ascii(record.message.dup.force_encoding('BINARY'))
      end

    h = {
      'timestamp' => record.timestamp.to_f,
      'message' => msg,
      'log_level' => record.log_level.to_s,
      'source' => record.source,
      'data' => record.data,
      'thread_id' => record.thread_id,
      'fiber_id' => record.fiber_id,
      'process_id' => record.process_id,
      'file' => record.file,
      'lineno' => record.lineno,
      'method' => record.method
    }

    h['timestamp'] = Time.at(record.timestamp).utc.iso8601(6) if iso8601_timestamps?

    Yajl::Encoder.encode(h) + "\n"
  end

  def iso8601_timestamps?
    @iso8601_timestamps
  end
end
