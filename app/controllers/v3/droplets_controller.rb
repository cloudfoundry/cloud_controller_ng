require 'presenters/v3/droplet_presenter'
require 'presenters/v3/paginated_list_presenter'
require 'fetchers/droplet_delete_fetcher'
require 'fetchers/droplet_list_fetcher'
require 'actions/droplet_delete'
require 'actions/droplet_copy'
require 'messages/droplets/droplets_list_message'
require 'messages/droplets/droplet_copy_message'
require 'cloud_controller/membership'
require 'controllers/v3/mixins/sub_resource'

class DropletsController < ApplicationController
  include SubResource

  def index
    message = DropletsListMessage.from_params(subresource_query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    if app_nested?
      app, dataset = DropletListFetcher.new(message: message).fetch_for_app
      app_not_found! unless app && can_read?(app.space.guid, app.organization.guid)
    elsif package_nested?
      package, dataset = DropletListFetcher.new(message: message).fetch_for_package
      package_not_found! unless package && can_read?(package.space.guid, package.space.organization.guid)
    else
      dataset = if can_read_globally?
                  DropletListFetcher.new(message: message).fetch_all
                else
                  DropletListFetcher.new(message: message).fetch_for_spaces(space_guids: readable_space_guids)
                end
    end

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(dataset: dataset, path: base_url(resource: 'droplets'), message: message)
  end

  def show
    droplet = DropletModel.where(guid: params[:guid]).eager(:space, space: :organization).all.first
    droplet_not_found! unless droplet && can_read?(droplet.space.guid, droplet.space.organization.guid)
    render status: :ok, json: Presenters::V3::DropletPresenter.new(droplet, show_secrets: can_see_secrets?(droplet.space))
  end

  def destroy
    droplet, space, org = DropletDeleteFetcher.new.fetch(params[:guid])
    droplet_not_found! unless droplet && can_read?(space.guid, org.guid)

    unauthorized! unless can_write?(space.guid)

    delete_action = DropletDelete.new(user_audit_info)
    deletion_job  = VCAP::CloudController::Jobs::DeleteActionJob.new(DropletModel, droplet.guid, delete_action)
    pollable_job = Jobs::Enqueuer.new(deletion_job, queue: 'cc-generic').enqueue_pollable

    url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new
    head HTTP::ACCEPTED, 'Location' => url_builder.build_url(path: "/v3/jobs/#{pollable_job.guid}")
  end

  def copy
    message = DropletCopyMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    source_droplet = DropletModel.where(guid: params[:source_guid]).eager(:space, space: :organization).all.first
    droplet_not_found! unless source_droplet && can_read?(source_droplet.space.guid, source_droplet.space.organization.guid)

    destination_app = AppModel.where(guid: message.app_guid).eager(:space, :organization).all.first
    app_not_found! unless destination_app && can_read?(destination_app.space.guid, destination_app.organization.guid)
    unauthorized! unless can_write?(destination_app.space.guid)

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
