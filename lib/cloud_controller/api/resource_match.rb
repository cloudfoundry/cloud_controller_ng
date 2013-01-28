# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  class ResourceMatch < RestController::Base

    def match
      return NotAuthorized unless user
      # TODO: replace with json_message
      descriptors = Yajl::Parser.parse(body)
      matched = ResourcePool.match_resources(descriptors)
      Yajl::Encoder.encode(matched)
    end

    put "/v2/resource_match", :match
  end
end
