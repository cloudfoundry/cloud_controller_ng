module Diego
  class Error < StandardError
  end

  class ClientError < Error
  end

  class DecodeError < Error
  end

  class EncodeError < Error
  end
end
