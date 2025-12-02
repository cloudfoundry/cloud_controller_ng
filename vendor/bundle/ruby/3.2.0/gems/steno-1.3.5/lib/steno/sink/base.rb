require 'rbconfig'
require 'thread'

module Steno
  module Sink
    WINDOWS = (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/)
  end
end

# Sinks represent the final destination for log records. They abstract storage
# mediums (like files) and transport layers (like sockets).
class Steno::Sink::Base
  attr_accessor :codec

  # @param [Steno::Codec::Base] formatter Transforms log records to their
  # raw, string-based representation that will be written to the underlying
  # sink.
  def initialize(codec = nil)
    @codec = codec
  end

  # Adds a record to be flushed at a later time.
  #
  # @param [Hash] record
  #
  # @return [nil]
  def add_record(record)
    raise NotImplementedError
  end

  # Flushes any buffered records.
  #
  # @return [nil]
  def flush
    raise NotImplementedError
  end
end
