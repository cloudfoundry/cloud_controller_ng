module VCAP::CloudController
  class DeletionError < StandardError; end

  class UserNotFoundDeletionError < DeletionError
    def initialize(user_id)
      underlying_error = VCAP::Errors::ApiError.new_from_details('UserNotFound', user_id)
      super(underlying_error.message)
    end
  end
end
