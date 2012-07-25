# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  class LegacyResources < LegacyApiBase
    controller.post "/resources" do
      VCAP::CloudController::ResourceMatch.new(@config, logger, request.body).match
    end
  end
end
