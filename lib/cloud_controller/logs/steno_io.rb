class StenoIO
  def initialize(logger, level)
    @logger = logger
    @level = level
  end

  def write(str)
    @logger.log(@level, str)
  end

  def puts(*args)
    args.each { |a| write("#{a}\n") }
    nil
  end

  def flush
    nil
  end

  def close
    nil
  end

  def sync
    true
  end

  def to_s
    @logger.name
  end
end
