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
    THREAD_LOCAL_KEY = '__steno_locals__'.freeze

    def data
      Thread.current[THREAD_LOCAL_KEY] ||= {}
    end

    def clear
      Thread.current[THREAD_LOCAL_KEY] = {}
    end
  end
end
