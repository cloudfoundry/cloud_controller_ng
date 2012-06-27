# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  class LegacyApiBase
    include VCAP::CloudController::Errors

    def initialize(config, logger, request)
      @config = config
      @logger = logger
      @request = request
    end

    def default_app_space
      raise NotAuthorized unless user
      app_space = user.default_app_space || user.app_spaces.first
      raise LegacyApiWithoutDefaultAppSpace unless app_space
      app_space
    end

    def user
      VCAP::CloudController::SecurityContext.current_user
    end

    def self.controller
      VCAP::CloudController::Controller
    end

    attr_accessor :logger, :request
  end
end
