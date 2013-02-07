class MockNATS
  class << self
    attr_accessor :client

    def start(*args)
      self.client = new
    end
  end
end
