require 'presenters/v3/droplet_presenter'
require 'handlers/droplets_handler'

module VCAP::CloudController
  class DropletsController < RestController::BaseController
    def self.dependencies
      [:droplets_handler, :droplet_presenter]
    end

    def inject_dependencies(dependencies)
      @droplets_handler = dependencies[:droplets_handler]
      @droplet_presenter = dependencies[:droplet_presenter]
    end

    get '/v3/droplets', :list
    def list
      pagination_options = PaginationOptions.from_params(params)
      paginated_result   = @droplets_handler.list(pagination_options, @access_context)
      droplets_json      = @droplet_presenter.present_json_list(paginated_result, '/v3/droplets')
      [HTTP::OK, droplets_json]
    end

    private

    def droplet_not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'Droplet not found')
    end

    def unauthorized!
      raise VCAP::Errors::ApiError.new_from_details('NotAuthorized')
    end

    def invalid_request!(message)
      raise VCAP::Errors::ApiError.new_from_details('InvalidRequest', message)
    end
  end
end
