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
      app, dataset = DropletListFetcher.fetch_for_app(message)
      app_not_found! unless app && permission_queryer.can_read_from_space?(app.space.id, app.space.organization_id)
    elsif package_nested?
      package, dataset = DropletListFetcher.fetch_for_package(message)
      package_not_found! unless package && permission_queryer.can_read_from_space?(package.space.id, package.space.organization_id)
    else
      dataset = if permission_queryer.can_read_globally?
                  DropletListFetcher.fetch_all(message)
                else
                  DropletListFetcher.fetch_for_spaces(message, permission_queryer.readable_space_guids)
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
    droplet = DropletModel.where(guid: hashed_params[:guid]).first

    droplet_not_found! unless droplet && permission_queryer.can_read_from_space?(droplet.space.id, droplet.space.organization_id)
    show_secrets = permission_queryer.can_read_secrets_in_space?(droplet.space.id, droplet.space.organization_id)
    render status: :ok, json: Presenters::V3::DropletPresenter.new(droplet, show_secrets: show_secrets)
  end

  def destroy
    droplet, space = DropletFetcher.new.fetch(hashed_params[:guid])
    droplet_not_found! unless droplet && permission_queryer.can_read_from_space?(space.id, space.organization_id)

    unauthorized! unless permission_queryer.can_write_to_active_space?(space.id)
    suspended! unless permission_queryer.is_space_active?(space.id)

    delete_action = DropletDelete.new(user_audit_info)
    deletion_job = VCAP::CloudController::Jobs::DeleteActionJob.new(DropletModel, droplet.guid, delete_action)
    pollable_job = Jobs::Enqueuer.new(deletion_job, queue: Jobs::Queues.generic).enqueue_pollable

    head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{pollable_job.guid}")
  end

  def update
    droplet, space = DropletFetcher.new.fetch(hashed_params[:guid])
    droplet_not_found! unless droplet && can_read_build?(space)
    if hashed_params[:body].key?(:image)
      unauthorized! unless permission_queryer.can_update_build_state?
    else
      unauthorized! unless permission_queryer.can_write_to_active_space?(space.id)
      suspended! unless permission_queryer.is_space_active?(space.id)
    end
    message = VCAP::CloudController::DropletUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    droplet = VCAP::CloudController::DropletUpdate.new.update(droplet, message)

    render status: :ok, json: Presenters::V3::DropletPresenter.new(droplet)
  end

  def create_copy
    message = DropletCopyMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    source_droplet = DropletModel.where(guid: hashed_params[:source_guid]).first

    droplet_not_found! unless source_droplet && permission_queryer.can_read_from_space?(source_droplet.space.id, source_droplet.space.organization_id)

    destination_app = AppModel.where(guid: message.app_guid).first

    app_not_found! unless destination_app && permission_queryer.can_read_from_space?(destination_app.space.id, destination_app.space.organization_id)
    unauthorized! unless permission_queryer.can_write_to_active_space?(destination_app.space.id)
    suspended! unless permission_queryer.is_space_active?(destination_app.space.id)

    DropletCopy.new(source_droplet).copy(destination_app, user_audit_info)
  end

  def create_fresh
    message = DropletCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    app = AppModel.where(guid: message.relationships_message.app_guid).first

    unprocessable_app!(message.relationships_message.app_guid) unless app && permission_queryer.can_read_from_space?(app.space.id, app.space.organization_id)
    unauthorized! unless permission_queryer.can_write_to_active_space?(app.space.id)
    suspended! unless permission_queryer.is_space_active?(app.space.id)

    DropletCreate.new.create(app, message, user_audit_info)
  end

  def upload
    message = DropletUploadMessage.create_from_params(hashed_params[:body])
    combine_messages(message.errors.full_messages) unless message.valid?

    droplet = DropletModel.where(guid: hashed_params[:guid]).first

    droplet_not_found! unless droplet && permission_queryer.can_read_from_space?(droplet.space.id, droplet.space.organization_id)

    unauthorized! unless permission_queryer.can_write_to_active_space?(droplet.space.id)
    suspended! unless permission_queryer.is_space_active?(droplet.space.id)

    unless droplet.state == DropletModel::AWAITING_UPLOAD_STATE
      unprocessable!('Droplet may be uploaded only once. Create a new droplet to upload bits.')
    end

    pollable_job = DropletUpload.new.upload_async(
      message: message,
      droplet: droplet,
      config: configuration,
      user_audit_info: user_audit_info
    )

    response.set_header('Location', url_builder.build_url(path: "/v3/jobs/#{pollable_job.guid}"))

    render status: :accepted, json: Presenters::V3::DropletPresenter.new(droplet)
  end

  def download
    droplet = DropletModel.where(guid: hashed_params[:guid]).first

    droplet_not_found! unless droplet && permission_queryer.can_read_from_space?(droplet.space.id, droplet.space.organization_id)

    unauthorized! unless permission_queryer.can_download_droplet?(droplet.space.id, droplet.space.organization_id)

    unless droplet.buildpack?
      unprocessable!("Cannot download droplets with 'docker' lifecycle.")
    end

    unless droplet.staged?
      unprocessable!('Only staged droplets can be downloaded.')
    end

    VCAP::CloudController::Repositories::DropletEventRepository.record_download(
      droplet,
      user_audit_info,
      droplet.app.name,
      droplet.space.guid,
      droplet.space.organization.guid,
    )

    send_droplet_blob(droplet)
  end

  private

  def can_read_build?(space)
    permission_queryer.can_update_build_state? || permission_queryer.can_read_from_space?(space.id, space.organization_id)
  end

  def send_droplet_blob(droplet)
    if droplet.blobstore_key.nil?
      resource_not_found_with_message!('Blobstore key not present on droplet. This may be due to a failed build.')
    end

    droplet_blobstore = CloudController::DependencyLocator.instance.droplet_blobstore
    BlobDispatcher.new(blobstore: droplet_blobstore, controller: self).send_or_redirect(guid: droplet.blobstore_key)
  rescue CloudController::Errors::BlobNotFound
    raise CloudController::Errors::ApiError.new_from_details('BlobstoreUnavailable')
  end

  def combine_messages(messages)
    unprocessable!("Uploaded droplet file is invalid: #{messages.join(', ')}")
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
