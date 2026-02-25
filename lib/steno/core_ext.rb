class Module
  def logger
    Steno.logger(name)
  end
end

class Object
  delegate :logger, to: :class
end
