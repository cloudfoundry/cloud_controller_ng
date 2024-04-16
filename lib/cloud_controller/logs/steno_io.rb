class StenoIO
  def initialize(logger, level)
    @logger = logger
    @level = level
  end

  def write(str)
    @logger.log(@level, str)
  end

  def sync
    true
  end
end
