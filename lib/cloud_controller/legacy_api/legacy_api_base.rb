# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  class LegacyApiBase
    include VCAP::CloudController::Errors

    def initialize(config, logger, request)
      @config = config
      @logger = logger
      @request = request
    end

    def default_space
      raise NotAuthorized unless user
      space = user.default_space || user.spaces.first
      raise LegacyApiWithoutDefaultSpace unless space
      space
    end

    def user
      VCAP::CloudController::SecurityContext.current_user
    end

    def self.controller
      VCAP::CloudController::Controller
    end

    attr_accessor :config, :logger, :request
  end
end
