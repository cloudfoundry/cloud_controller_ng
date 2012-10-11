module VCAP
  class RingBuffer < Array
    attr_reader :max_size

    def initialize(max_size)
      @max_size = max_size
    end

    def push(item)
      super
      self.shift if size > @max_size
    end

    alias :<< :push
  end
end
