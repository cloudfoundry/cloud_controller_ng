module VCAP::CloudController
  class ResourceMatchesController < RestController::BaseController
    put '/v2/resource_match', :match
    def match
      return ApiError.new_from_details('NotAuthorized') unless user
      FeatureFlag.raise_unless_enabled!(:app_bits_upload)

      if bits_service_resource_pool
        match_with_bits_service
      else
        fingerprints_all_clientside_bits = parse_fingerprints_in(body)
        fingerprints_existing_in_blobstore = ResourcePool.instance.match_resources(fingerprints_all_clientside_bits)
        MultiJson.dump(fingerprints_existing_in_blobstore)
      end
    end

    private

    def bits_service_resource_pool
      CloudController::DependencyLocator.instance.bits_service_resource_pool
    end

    def match_with_bits_service
      bits_service_resource_pool.matches(body.read).body
    rescue BitsService::Errors::Error => e
      raise CloudController::Errors::ApiError.new_from_details('BitsServiceError', e.message)
    end

    def parse_fingerprints_in(payload)
      fingerprints_all_clientside_bits = MultiJson.load(payload)
      unless fingerprints_all_clientside_bits.is_a?(Array)
        raise CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', 'must be an array.')
      end
      fingerprints_all_clientside_bits
    rescue MultiJson::ParseError => e
      raise CloudController::Errors::ApiError.new_from_details('MessageParseError', e.message)
    end
  end
end
