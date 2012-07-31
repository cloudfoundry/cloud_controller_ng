# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  class LegacyResources < LegacyApiBase
    def match
      VCAP::CloudController::ResourceMatch.new(@config, logger, env, params, body).dispatch(:match)
    end

    post "/resources", :match
  end
end
