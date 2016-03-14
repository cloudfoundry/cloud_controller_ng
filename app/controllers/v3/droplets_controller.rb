require 'presenters/v3/droplet_presenter'
require 'queries/droplet_delete_fetcher'
require 'queries/droplet_list_fetcher'
require 'actions/droplet_delete'
require 'actions/droplet_create'
require 'messages/droplet_create_message'
require 'messages/droplets_list_message'
require 'cloud_controller/membership'
require 'controllers/v3/mixins/app_subresource'

class DropletsController < ApplicationController
  include AppSubresource

  def index
    message = DropletsListMessage.from_params(app_subresource_query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    pagination_options = PaginationOptions.from_params(query_params)
    invalid_param!(pagination_options.errors.full_messages) unless pagination_options.valid?

    if app_nested?
      app, paginated_result = list_fetcher.fetch_for_app(app_guid: params[:app_guid], pagination_options: pagination_options, message: message)
      app_not_found! unless app && can_read?(app.space.guid, app.organization.guid)
    else
      paginated_result = if roles.admin?
                           list_fetcher.fetch_all(pagination_options: pagination_options, message: message)
                         else
                           list_fetcher.fetch_for_spaces(space_guids: readable_space_guids, pagination_options: pagination_options, message: message)
                         end
    end

    render status: :ok, json: droplet_presenter.present_json_list(paginated_result, base_url(resource: 'droplets'), message)
  end

  def show
    droplet = DropletModel.where(guid: params[:guid]).eager(:space, space: :organization).all.first
    droplet_not_found! unless droplet && can_read?(droplet.space.guid, droplet.space.organization.guid)
    render status: :ok, json: droplet_presenter.present_json(droplet)
  end

  def destroy
    droplet, space, org = DropletDeleteFetcher.new.fetch(params[:guid])
    droplet_not_found! unless droplet && can_read?(space.guid, org.guid)

    unauthorized! unless can_delete?(space.guid)

    DropletDelete.new.delete(droplet)

    head :no_content
  end

  def create
    staging_message = DropletCreateMessage.create_from_http_request(params[:body])
    unprocessable!(staging_message.errors.full_messages) unless staging_message.valid?

    package = PackageModel.where(guid: params[:package_guid]).eager(:app, :space, space: :organization, app: :buildpack_lifecycle_data).all.first
    package_not_found! unless package && can_read?(package.space.guid, package.space.organization.guid)
    staging_in_progress! if package.app.staging_in_progress?

    if package.type == VCAP::CloudController::PackageModel::DOCKER_TYPE && !roles.admin?
      FeatureFlag.raise_unless_enabled!('diego_docker')
    end

    unauthorized! unless can_create?(package.space.guid)

    lifecycle = LifecycleProvider.provide(package, staging_message)
    unprocessable!(lifecycle.errors.full_messages) unless lifecycle.valid?

    droplet = DropletCreate.new.create_and_stage(package, lifecycle, stagers)

    render status: :created, json: droplet_presenter.present_json(droplet)
  rescue DropletCreate::InvalidPackage => e
    invalid_request!(e.message)
  rescue DropletCreate::SpaceQuotaExceeded
    unable_to_perform!('Staging request', "space's memory limit exceeded")
  rescue DropletCreate::OrgQuotaExceeded
    unable_to_perform!('Staging request', "organization's memory limit exceeded")
  rescue DropletCreate::DiskLimitExceeded
    unable_to_perform!('Staging request', 'disk limit exceeded')
  end

  private

  def can_create?(space_guid)
    roles.admin? || membership.has_any_roles?([Membership::SPACE_DEVELOPER], space_guid)
  end
  alias_method :can_delete?, :can_create?

  def droplet_not_found!
    resource_not_found!(:droplet)
  end

  def package_not_found!
    resource_not_found!(:package)
  end

  def staging_in_progress!
    raise VCAP::Errors::ApiError.new_from_details('StagingInProgress')
  end

  def unable_to_perform!(operation, message)
    raise VCAP::Errors::ApiError.new_from_details('UnableToPerform', operation, message)
  end

  def droplet_presenter
    @droplet_presenter ||= DropletPresenter.new
  end

  def list_fetcher
    DropletListFetcher.new
  end

  def stagers
    CloudController::DependencyLocator.instance.stagers
  end
end
