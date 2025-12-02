class Module
  def logger
    Steno.logger(name)
  end
end

class Object
  def logger
    self.class.logger
  end
end
