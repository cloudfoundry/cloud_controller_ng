module Diego
  class Error < StandardError
  end

  class RequestError < Error
  end

  class ResponseError < Error
  end

  class DecodeError < Error
  end

  class EncodeError < Error
  end
end
