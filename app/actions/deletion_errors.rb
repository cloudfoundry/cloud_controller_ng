module VCAP::CloudController
  class DeletionError < StandardError
    attr_reader :underlying_error

    def initialize(msg, underlying_error)
      super(msg)
      @underlying_error = underlying_error
    end
  end

  class UserNotFoundDeletionError < DeletionError
    def initialize(user_id)
      underlying_error = VCAP::Errors::ApiError.new_from_details('UserNotFound', user_id)
      super('Please delete the service binding association for your service instance.',
            underlying_error)
    end
  end

  class ServiceBindingDeletionError < DeletionError
    def initialize(underlying_error)
      super('Please delete the service binding association for your service instance.',
            underlying_error)
    end
  end

  class ServiceInstanceDeletionError < DeletionError
    def initialize(underlying_error)
      super('Please delete the service instance association for your space.',
            underlying_error)
    end
  end
end
