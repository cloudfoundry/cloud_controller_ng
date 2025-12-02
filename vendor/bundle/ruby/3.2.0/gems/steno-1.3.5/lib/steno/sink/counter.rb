require 'steno/sink/base'

module Steno
  module Sink
  end
end

class Steno::Sink::Counter < Steno::Sink::Base
  def initialize
    # Map of String -> numeric count
    @counts = {}
    @mutex = Mutex.new
  end

  def add_record(record)
    level = record.log_level.to_s

    @mutex.synchronize do
      @counts[level] = 0 unless @counts[level]
      @counts[level] += 1
    end
  end

  def flush; end

  def to_json(*_args)
    hash = {}
    @mutex.synchronize do
      Steno::Logger::LEVELS.keys.each do |level_name|
        hash[level_name] = @counts.fetch(level_name.to_s, 0)
      end
    end
    Yajl::Encoder.encode(hash)
  end

  # Provide a map of string level -> count. This is thread-safe, the return value is a copy.
  def counts
    @mutex.synchronize { @counts.dup }
  end
end
