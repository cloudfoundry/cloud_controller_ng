module TrafficController
  class Error < StandardError
  end

  class RequestError < Error
  end

  class ResponseError < Error
  end

  class DecodeError < Error
  end

  class ParseError < Error
  end
end
