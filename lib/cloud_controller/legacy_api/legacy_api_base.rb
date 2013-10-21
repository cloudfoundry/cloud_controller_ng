module VCAP::CloudController
  class LegacyApiBase < RestController::Base
    include VCAP::Errors

    def default_space
      raise NotAuthorized unless user
      space = user.default_space || user.spaces.first
      raise LegacyApiWithoutDefaultSpace unless space
      space
    end

    def has_default_space?
      raise NotAuthorized unless user
      return true if user.default_space || !user.spaces.empty?
      return false
    end
  end
end
