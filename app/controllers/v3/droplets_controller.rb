require 'presenters/v3/droplet_presenter'
require 'queries/droplet_delete_fetcher'
require 'actions/droplet_delete'
require 'queries/droplet_list_fetcher'

module VCAP::CloudController
  class DropletsController < RestController::BaseController
    def self.dependencies
      [:droplet_presenter]
    end

    def inject_dependencies(dependencies)
      @droplet_presenter = dependencies[:droplet_presenter]
    end

    get '/v3/droplets', :list
    def list
      check_read_permissions!

      pagination_options = PaginationOptions.from_params(params)
      invalid_param!(pagination_options.errors.full_messages) unless pagination_options.valid?
      invalid_param!("Unknown query param(s) '#{params.keys.join("', '")}'") if params.any?

      if membership.admin?
        paginated_result = DropletListFetcher.new.fetch_all(pagination_options)
      else
        space_guids = membership.space_guids_for_roles(
          [Membership::SPACE_DEVELOPER,
           Membership::SPACE_MANAGER,
           Membership::SPACE_AUDITOR,
           Membership::ORG_MANAGER])
        paginated_result = DropletListFetcher.new.fetch(pagination_options, space_guids)
      end

      [HTTP::OK, @droplet_presenter.present_json_list(paginated_result, '/v3/droplets')]
    end

    get '/v3/droplets/:guid', :show
    def show(guid)
      check_read_permissions!

      droplet = DropletModel.where(guid: guid).eager(:space, space: :organization).all.first
      droplet_not_found! if droplet.nil? || !can_read?(droplet.space.guid, droplet.space.organization.guid)

      [HTTP::OK, @droplet_presenter.present_json(droplet)]
    end

    delete '/v3/droplets/:guid', :delete
    def delete(guid)
      check_write_permissions!

      droplet_delete_fetcher = DropletDeleteFetcher.new
      droplet, space, org = droplet_delete_fetcher.fetch(guid)
      droplet_not_found! if droplet.nil? || !can_read?(space.guid, org.guid)

      unauthorized! unless can_delete?(space.guid)

      DropletDelete.new.delete(droplet)

      [HTTP::NO_CONTENT]
    end

    def membership
      @membership ||= Membership.new(current_user)
    end

    private

    def can_read?(space_guid, org_guid)
      membership.has_any_roles?([Membership::SPACE_DEVELOPER,
                                 Membership::SPACE_MANAGER,
                                 Membership::SPACE_AUDITOR,
                                 Membership::ORG_MANAGER], space_guid, org_guid)
    end

    def can_delete?(space_guid)
      membership.has_any_roles?([Membership::SPACE_DEVELOPER], space_guid)
    end

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
