require 'presenters/v3/droplet_presenter'
require 'presenters/v3/paginated_list_presenter'
require 'fetchers/droplet_delete_fetcher'
require 'fetchers/droplet_list_fetcher'
require 'actions/droplet_delete'
require 'actions/droplet_copy'
require 'messages/droplets_list_message'
require 'messages/droplet_copy_message'
require 'cloud_controller/membership'
require 'controllers/v3/mixins/app_sub_resource'

class DropletsController < ApplicationController
  include AppSubResource

  def index
    message = DropletsListMessage.from_params(subresource_query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    if app_nested?
      app, dataset = DropletListFetcher.new(message: message).fetch_for_app
      app_not_found! unless app && permission_queryer.can_read_from_space?(app.space.guid, app.organization.guid)
    elsif package_nested?
      package, dataset = DropletListFetcher.new(message: message).fetch_for_package
      package_not_found! unless package && permission_queryer.can_read_from_space?(package.space.guid, package.space.organization.guid)
    else
      dataset = if permission_queryer.can_read_globally?
                  DropletListFetcher.new(message: message).fetch_all
                else
                  DropletListFetcher.new(message: message).fetch_for_spaces(space_guids: permission_queryer.readable_space_guids)
                end
    end

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::DropletPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: base_url(resource: 'droplets'),
      message: message
    )
  end

  def show
    droplet = DropletModel.where(guid: hashed_params[:guid]).eager(:space, space: :organization).all.first
    droplet_not_found! unless droplet && permission_queryer.can_read_from_space?(droplet.space.guid, droplet.space.organization.guid)
    show_secrets = permission_queryer.can_read_secrets_in_space?(droplet.space.guid, droplet.space.organization.guid)
    render status: :ok, json: Presenters::V3::DropletPresenter.new(droplet, show_secrets: show_secrets)
  end

  def destroy
    droplet, space, org = DropletDeleteFetcher.new.fetch(hashed_params[:guid])
    droplet_not_found! unless droplet && permission_queryer.can_read_from_space?(space.guid, org.guid)

    unauthorized! unless permission_queryer.can_write_to_space?(space.guid)

    delete_action = DropletDelete.new(user_audit_info)
    deletion_job = VCAP::CloudController::Jobs::DeleteActionJob.new(DropletModel, droplet.guid, delete_action)
    pollable_job = Jobs::Enqueuer.new(deletion_job, queue: 'cc-generic').enqueue_pollable

    url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new
    head HTTP::ACCEPTED, 'Location' => url_builder.build_url(path: "/v3/jobs/#{pollable_job.guid}")
  end

  def copy
    message = DropletCopyMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    source_droplet = DropletModel.where(guid: hashed_params[:source_guid]).eager(:space, space: :organization).all.first
    droplet_not_found! unless source_droplet && permission_queryer.can_read_from_space?(source_droplet.space.guid, source_droplet.space.organization.guid)

    destination_app = AppModel.where(guid: message.app_guid).eager(:space, :organization).all.first
    app_not_found! unless destination_app && permission_queryer.can_read_from_space?(destination_app.space.guid, destination_app.organization.guid)
    unauthorized! unless permission_queryer.can_write_to_space?(destination_app.space.guid)

    droplet = DropletCopy.new(source_droplet).copy(destination_app, user_audit_info)

    render status: :created, json: Presenters::V3::DropletPresenter.new(droplet)
  rescue DropletCopy::InvalidCopyError => e
    unprocessable!(e.message)
  end

  private

  def stagers
    CloudController::DependencyLocator.instance.stagers
  end

  def droplet_not_found!
    resource_not_found!(:droplet)
  end

  def package_not_found!
    resource_not_found!(:package)
  end
end
