# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  class LegacyApiBase
    include VCAP::CloudController::Errors

    def initialize(config, logger, request)
      @config = config
      @logger = logger
      @request = request
      @user = Models::User.current_user
    end

    def default_app_space
      raise NotAuthorized unless @user
      raise LegacyApiWithoutDefaultAppSpace unless @user.default_app_space
      @user.default_app_space
    end

    def self.controller
      VCAP::CloudController::Controller
    end

    attr_accessor :logger, :user, :request
  end
end
