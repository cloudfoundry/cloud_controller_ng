require 'presenters/v3/droplet_presenter'
require 'handlers/droplets_handler'
require 'queries/droplet_delete_fetcher'
require 'actions/droplet_delete'

module VCAP::CloudController
  class DropletsController < RestController::ModelController
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

    get '/v3/droplets/:guid', :show
    def show(guid)
      droplet = @droplets_handler.show(guid, @access_context)
      droplet_not_found! if droplet.nil?
      droplet_json = @droplet_presenter.present_json(droplet)
      [HTTP::OK, droplet_json]
    rescue DropletsHandler::Unauthorized
      unauthorized!
    end

    delete '/v3/droplets/:guid', :delete
    def delete(guid)
      check_write_permissions!

      droplet_delete_fetcher = DropletDeleteFetcher.new(current_user)
      droplet_dataset        = droplet_delete_fetcher.fetch(guid)
      droplet_not_found! if droplet_dataset.empty?

      DropletDelete.new.delete(droplet_dataset)

      [HTTP::NO_CONTENT]
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
