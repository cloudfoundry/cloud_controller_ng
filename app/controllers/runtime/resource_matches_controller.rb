module VCAP::CloudController
  class ResourceMatchesController < RestController::BaseController
    put '/v2/resource_match', :match
    def match
      return ApiError.new_from_details('NotAuthorized') unless user
      FeatureFlag.raise_unless_enabled!('app_bits_upload') unless SecurityContext.admin?

      begin
        fingerprints_all_clientside_bits = MultiJson.load(body)
      rescue MultiJson::ParseError => e
        raise Errors::ApiError.new_from_details('MessageParseError', e.message)
      end

      unless fingerprints_all_clientside_bits.is_a?(Array)
        raise Errors::ApiError.new_from_details('UnprocessableEntity', 'must be an array.')
      end

      fingerprints_existing_in_blobstore = ResourcePool.instance.match_resources(fingerprints_all_clientside_bits)
      MultiJson.dump(fingerprints_existing_in_blobstore)
    end
  end
end
