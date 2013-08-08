module VCAP::CloudController
  class ResourceMatchesController < RestController::Base
    def match
      return NotAuthorized unless user
      # TODO: replace with json_message
      fingerprints_all_clientside_bits = Yajl::Parser.parse(body)
      fingerprints_existing_in_blobstore = ResourcePool.instance.match_resources(fingerprints_all_clientside_bits)
      Yajl::Encoder.encode(fingerprints_existing_in_blobstore)
    end

    put "/v2/resource_match", :match
  end
end
