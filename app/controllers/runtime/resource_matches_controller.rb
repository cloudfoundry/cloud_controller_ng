require 'cloud_controller/resource_pool_wrapper'
require 'cloud_controller/bits_service_resource_pool_wrapper'

module VCAP::CloudController
  class ResourceMatchesController < RestController::BaseController
    put '/v2/resource_match', :match
    def match
      return ApiError.new_from_details('NotAuthorized') unless user
      FeatureFlag.raise_unless_enabled!(:app_bits_upload)

      CloudController::DependencyLocator.instance.resource_pool_wrapper.new(body).call
    end
  end
end
