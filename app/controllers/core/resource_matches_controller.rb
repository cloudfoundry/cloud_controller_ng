module VCAP::CloudController
  class ResourceMatchesController < RestController::Base
    def match
      return NotAuthorized unless user
      # TODO: replace with json_message
      descriptors = Yajl::Parser.parse(body)
      matched = ResourcePool.instance.match_resources(descriptors)
      Yajl::Encoder.encode(matched)
    end

    put "/v2/resource_match", :match
  end
end
