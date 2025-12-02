require 'fiber'
require 'thread'

class Fiber
  def __steno_context_data__
    @__steno_context_data__ ||= {}
  end

  def __steno_clear_context_data__
    @__steno_context_data__ = {}
  end
end

module Steno
end

module Steno::Context
  class Base
    def data
      raise NotImplementedError
    end

    def clear
      raise NotImplementedError
    end
  end

  class Null < Base
    def data
      {}
    end

    def clear
      nil
    end
  end

  class ThreadLocal < Base
    THREAD_LOCAL_KEY = '__steno_locals__'

    def data
      Thread.current[THREAD_LOCAL_KEY] ||= {}
    end

    def clear
      Thread.current[THREAD_LOCAL_KEY] = {}
    end
  end

  class FiberLocal < Base
    def data
      Fiber.current.__steno_context_data__
    end

    def clear
      Fiber.current.__steno_clear_context_data__
    end
  end
end
