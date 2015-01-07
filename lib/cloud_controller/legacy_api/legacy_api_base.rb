module VCAP::CloudController
  class LegacyApiBase < RestController::BaseController
    include VCAP::Errors

    def default_space
      raise Errors::ApiError.new_from_details('NotAuthorized') unless user
      space = user.default_space || user.spaces.first
      raise ApiError.new_from_details('LegacyApiWithoutDefaultSpace') unless space
      space
    end

    def has_default_space?
      raise Errors::ApiError.new_from_details('NotAuthorized') unless user
      return true if user.default_space || !user.spaces.empty?
      false
    end
  end
end
