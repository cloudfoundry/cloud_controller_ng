require 'steno/sink/base'

module Steno
  module Sink
  end
end

class Steno::Sink::IO < Steno::Sink::Base
  class << self
    # Returns a new sink configured to append to the file at path.
    #
    # @param [String] path
    # @param [Hash]   If the key :autoflush is set to true, encoded records
    #                 will not be buffered by Ruby. The key :max_retries
    #                 is forwarded to Steno::Sink::IO object during creation.
    # @return [Steno::Sink::IO]
    def for_file(path, opts = {})
      autoflush = true
      autoflush = opts[:autoflush] if opts.include?(:autoflush)

      io = File.open(path, 'a+')

      io.sync = autoflush

      new(io, max_retries: opts[:max_retries])
    end
  end

  attr_reader :max_retries

  # @param [IO] io     The IO object that will be written to
  # @param [Hash] opts Key :codec is used to specify a codec inheriting from
  #                    Steno::Codec::Base.
  #                    Key :max_retries takes an integer value which specifies
  #                    the number of times the write operation can be retried
  #                    when IOError is raised while writing a record.
  def initialize(io, opts = {})
    super(opts[:codec])

    @max_retries = opts[:max_retries] || -1
    @io_lock = Mutex.new
    @io = io
  end

  def add_record(record)
    bytes = @codec.encode_record(record)

    @io_lock.synchronize do
      retries = 0
      begin
        @io.write(bytes)
      rescue IOError => e
        raise e unless retries < @max_retries

        retries += 1
        retry
      end
    end

    nil
  end

  def flush
    @io_lock.synchronize { @io.flush }

    nil
  end
end
