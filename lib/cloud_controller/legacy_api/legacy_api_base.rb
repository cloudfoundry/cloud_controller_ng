# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  class LegacyApiBase
    include VCAP::CloudController::Errors

    def initialize(user, config, logger, request)
      @config = config
      @logger = logger
      @request = request
      @user = user
    end

    def default_app_space
      raise NotAuthorized unless @user
      app_space = @user.default_app_space || @user.app_spaces.first
      raise LegacyApiWithoutDefaultAppSpace unless app_space
      app_space
    end

    def self.controller
      VCAP::CloudController::Controller
    end

    attr_accessor :logger, :user, :request
  end
end
