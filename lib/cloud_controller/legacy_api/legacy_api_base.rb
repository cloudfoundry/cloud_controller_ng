# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  class LegacyApiBase < RestController::Base
    include VCAP::CloudController::Errors

    def default_space
      raise NotAuthorized unless user
      space = user.default_space || user.spaces.first
      raise LegacyApiWithoutDefaultSpace unless space
      space
    end
  end
end
