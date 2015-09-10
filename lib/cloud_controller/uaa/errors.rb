module VCAP::CloudController
  class UaaError < StandardError; end

  class UaaResourceNotFound < UaaError
    def message
      'The requested resource was not found in the UAA'
    end
  end

  class UaaResourceAlreadyExists < UaaError
    def message
      'The requested resource already exists in the UAA'
    end
  end

  class UaaResourceInvalid < UaaError
    def message
      'The UAA request was invalid'
    end
  end

  class UaaUnavailable < UaaError
    def message
      'The UAA was unavailable'
    end
  end

  class UaaUnexpectedResponse < UaaError
    def message
      'The UAA returned an unexpected error'
    end
  end

  class UaaEndpointDisabled < UaaError
    def message
      'The UAA endpoint is disabled'
    end
  end
end
