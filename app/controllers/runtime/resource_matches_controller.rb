module VCAP::CloudController
  class ResourceMatchesController < RestController::BaseController
    put '/v2/resource_match', :match
    def match
      return ApiError.new_from_details('NotAuthorized') unless user
      FeatureFlag.raise_unless_enabled!(:app_bits_upload)

      if bits_service_resource_pool
        begin
          response = bits_service_resource_pool.matches(body.read)
          return response.body
        rescue BitsService::Errors::Error => e
          raise CloudController::Errors::ApiError.new_from_details('BitsServiceError', e.message)
        end
      end

      begin
        fingerprints_all_clientside_bits = MultiJson.load(body)
      rescue MultiJson::ParseError => e
        raise CloudController::Errors::ApiError.new_from_details('MessageParseError', e.message)
      end

      unless fingerprints_all_clientside_bits.is_a?(Array)
        raise CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', 'must be an array.')
      end

      fingerprints_existing_in_blobstore = ResourcePool.instance.match_resources(fingerprints_all_clientside_bits)
      MultiJson.dump(fingerprints_existing_in_blobstore)
    end

    private

    def bits_service_resource_pool
      CloudController::DependencyLocator.instance.bits_service_resource_pool
    end
  end
end
