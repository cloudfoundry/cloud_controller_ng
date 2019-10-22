require 'presenters/v3/droplet_presenter'
require 'presenters/v3/paginated_list_presenter'
require 'fetchers/droplet_fetcher'
require 'fetchers/droplet_list_fetcher'
require 'actions/droplet_delete'
require 'actions/droplet_copy'
require 'actions/droplet_update'
require 'actions/droplet_upload'
require 'messages/droplets_list_message'
require 'messages/droplet_copy_message'
require 'messages/droplet_create_message'
require 'messages/droplet_update_message'
require 'messages/droplet_upload_message'
require 'cloud_controller/membership'
require 'controllers/v3/mixins/app_sub_resource'

class DropletsController < ApplicationController
  include AppSubResource

  def create
    droplet = hashed_params[:source_guid] ? create_copy : create_fresh

    render status: :created, json: Presenters::V3::DropletPresenter.new(droplet)
  rescue DropletCopy::InvalidCopyError, DropletCreate::Error => e
    unprocessable!(e.message)
  end

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
    droplet = DropletModel.where(guid: hashed_params[:guid]).eager(:space, space: :organization).first
    droplet_not_found! unless droplet && permission_queryer.can_read_from_space?(droplet.space.guid, droplet.space.organization.guid)
    show_secrets = permission_queryer.can_read_secrets_in_space?(droplet.space.guid, droplet.space.organization.guid)
    render status: :ok, json: Presenters::V3::DropletPresenter.new(droplet, show_secrets: show_secrets)
  end

  def destroy
    droplet, space, org = DropletFetcher.new.fetch(hashed_params[:guid])
    droplet_not_found! unless droplet && permission_queryer.can_read_from_space?(space.guid, org.guid)

    unauthorized! unless permission_queryer.can_write_to_space?(space.guid)

    delete_action = DropletDelete.new(user_audit_info)
    deletion_job = VCAP::CloudController::Jobs::DeleteActionJob.new(DropletModel, droplet.guid, delete_action)
    pollable_job = Jobs::Enqueuer.new(deletion_job, queue: Jobs::Queues.generic).enqueue_pollable

    url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new
    head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{pollable_job.guid}")
  end

  def update
    droplet, space, org = DropletFetcher.new.fetch(hashed_params[:guid])
    droplet_not_found! unless droplet && permission_queryer.can_read_from_space?(space.guid, org.guid)
    unauthorized! unless permission_queryer.can_write_to_space?(space.guid)

    message = VCAP::CloudController::DropletUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    droplet = VCAP::CloudController::DropletUpdate.new.update(droplet, message)

    render status: :ok, json: Presenters::V3::DropletPresenter.new(droplet)
  end

  def create_copy
    message = DropletCopyMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    source_droplet = DropletModel.where(guid: hashed_params[:source_guid]).eager(:space, space: :organization).first
    droplet_not_found! unless source_droplet && permission_queryer.can_read_from_space?(source_droplet.space.guid, source_droplet.space.organization.guid)

    destination_app = AppModel.where(guid: message.app_guid).eager(:space, :organization).first
    app_not_found! unless destination_app && permission_queryer.can_read_from_space?(destination_app.space.guid, destination_app.organization.guid)
    unauthorized! unless permission_queryer.can_write_to_space?(destination_app.space.guid)

    DropletCopy.new(source_droplet).copy(destination_app, user_audit_info)
  end

  def create_fresh
    message = DropletCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    app = AppModel.where(guid: message.relationships_message.app_guid).eager(:space, :organization).first
    unprocessable_app!(message.relationships_message.app_guid) unless app && permission_queryer.can_read_from_space?(app.space.guid, app.organization.guid)
    unauthorized! unless permission_queryer.can_write_to_space?(app.space.guid)

    DropletCreate.new.create(app, message, user_audit_info)
  end

  def upload
    message = DropletUploadMessage.create_from_params(hashed_params[:body])
    combine_messages(message.errors.full_messages) unless message.valid?

    droplet = DropletModel.where(guid: hashed_params[:guid]).eager(:app, :space).first
    resource_not_found_with_message!("Droplet with guid '#{hashed_params[:guid]}' does not exist, or you do not have access to it.") unless droplet

    unauthorized! unless permission_queryer.can_write_to_space?(droplet.space.guid)

    unless droplet.state == DropletModel::AWAITING_UPLOAD_STATE
      unprocessable!('Droplet may be uploaded only once. Create a new droplet to upload bits.')
    end

    pollable_job = DropletUpload.new.upload_async(
      message: message,
      droplet: droplet,
      config: configuration,
      user_audit_info: user_audit_info
    )

    url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new
    response.set_header('Location', url_builder.build_url(path: "/v3/jobs/#{pollable_job.guid}"))

    render status: :accepted, json: Presenters::V3::DropletPresenter.new(droplet)
  end

  private

  def combine_messages(messages)
    unprocessable!("Uploaded droplet file is invalid: #{messages.join(', ')}")
  end

  def stagers
    CloudController::DependencyLocator.instance.stagers
  end

  def unprocessable_app!(app_guid)
    unprocessable!("App with guid \"#{app_guid}\" does not exist, or you do not have access to it.")
  end

  def droplet_not_found!
    resource_not_found!(:droplet)
  end

  def package_not_found!
    resource_not_found!(:package)
  end
end
