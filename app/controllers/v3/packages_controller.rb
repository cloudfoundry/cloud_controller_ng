require 'presenters/v3/package_presenter'
require 'presenters/v3/paginated_list_presenter'
require 'fetchers/package_fetcher'
require 'fetchers/package_list_fetcher'
require 'actions/package_delete'
require 'actions/package_upload'
require 'actions/package_create'
require 'actions/package_copy'
require 'actions/package_update'
require 'messages/package_create_message'
require 'messages/package_update_message'
require 'messages/package_upload_message'
require 'messages/packages_list_message'
require 'controllers/v3/mixins/app_sub_resource'

class PackagesController < ApplicationController
  include AppSubResource

  def index
    message = PackagesListMessage.from_params(subresource_query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    if app_nested?
      app, dataset = PackageListFetcher.fetch_for_app(message:)

      app_not_found! unless app && permission_queryer.can_read_from_space?(app.space.id, app.space.organization_id)
    else
      dataset = if permission_queryer.can_read_globally?
                  PackageListFetcher.fetch_all(message:)
                else
                  PackageListFetcher.fetch_for_spaces(message: message, space_guids: permission_queryer.readable_space_guids)
                end
    end

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::PackagePresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: base_url(resource: 'packages'),
      message: message
    )
  end

  def upload
    FeatureFlag.raise_unless_enabled!(:app_bits_upload)

    opts = hashed_params[:body].dup.symbolize_keys
    begin
      if opts[:resources].present?
        opts[:resources] = MultiJson.load(opts[:resources])
        opts[:resources] = V2V3ResourceTranslator.new(opts[:resources]).v2_fingerprints_body
      end
    rescue MultiJson::ParseError
      unprocessable!('Resources must be valid JSON.')
    end

    message = PackageUploadMessage.create_from_params(opts)
    unprocessable!(message.errors.full_messages) unless message.valid?

    package = PackageModel.where(guid: hashed_params[:guid]).first
    package_not_found! unless package && permission_queryer.can_read_from_space?(package.space.id, package.space.organization_id)
    unauthorized! unless permission_queryer.can_write_to_active_space?(package.space.id)
    suspended! unless permission_queryer.is_space_active?(package.space.id)

    unprocessable!('Package type must be bits.') unless package.type == 'bits'
    bits_already_uploaded! if package.state != PackageModel::CREATED_STATE

    begin
      PackageUpload.new.upload_async(
        message: message,
        package: package,
        config: configuration,
        user_audit_info: user_audit_info
      )
    rescue PackageUpload::InvalidPackage => e
      unprocessable!(e.message)
    end

    TelemetryLogger.v3_emit(
      'upload-package',
      {
        'app-id' => package.app_guid,
        'user-id' => current_user.guid
      }
    )
    render status: :ok, json: Presenters::V3::PackagePresenter.new(package)
  end

  def download
    package = PackageModel.where(guid: hashed_params[:guid]).first

    package_not_found! unless package && permission_queryer.can_read_from_space?(package.space.id, package.space.organization_id)
    unauthorized! unless permission_queryer.can_read_secrets_in_space?(package.space.id, package.space.organization_id)

    unprocessable!('Package type must be bits.') unless package.type == 'bits'
    unprocessable!('Package has no bits to download.') unless package.state == 'READY'
    unprocessable!('Unable to download packages when an image registry is used to store packages') if VCAP::CloudController::Config.config.package_image_registry_configured?

    VCAP::CloudController::Repositories::PackageEventRepository.record_app_package_download(
      package,
      user_audit_info
    )

    send_package_blob(package)
  end

  def show
    package = PackageModel.where(guid: hashed_params[:guid]).first

    package_not_found! unless package && permission_queryer.can_read_from_space?(package.space.id, package.space.organization_id)

    render status: :ok, json: Presenters::V3::PackagePresenter.new(package)
  end

  def create
    package = hashed_params[:source_guid] ? create_copy : create_fresh

    render status: :created, json: Presenters::V3::PackagePresenter.new(package)
  rescue PackageCopy::InvalidPackage, PackageCreate::InvalidPackage => e
    unprocessable!(e.message)
  end

  def update
    message = VCAP::CloudController::PackageUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    package, space = PackageFetcher.new.fetch(hashed_params[:guid])
    package_not_found! unless package && permission_queryer.can_read_from_space?(space.id, space.organization_id)
    unprocessable_non_docker_package_update! if package.type != PackageModel::DOCKER_TYPE && (message.username || message.password)
    unauthorized! unless permission_queryer.can_write_to_active_space?(space.id)
    suspended! unless permission_queryer.is_space_active?(space.id)

    package = PackageUpdate.new.update(package, message)

    render status: :ok, json: Presenters::V3::PackagePresenter.new(package)
  end

  def destroy
    package = PackageModel.where(guid: hashed_params[:guid]).first

    package_not_found! unless package && permission_queryer.can_read_from_space?(package.space.id, package.space.organization_id)
    unauthorized! unless permission_queryer.can_write_to_active_space?(package.space.id)
    suspended! unless permission_queryer.is_space_active?(package.space.id)

    delete_action = PackageDelete.new(user_audit_info)
    deletion_job = VCAP::CloudController::Jobs::DeleteActionJob.new(PackageModel, package.guid, delete_action)
    job = Jobs::Enqueuer.new(deletion_job, queue: Jobs::Queues.generic).enqueue_pollable

    head HTTP::ACCEPTED, 'Location' => url_builder.build_url(path: "/v3/jobs/#{job.guid}")
  end

  private

  def create_fresh
    message = PackageCreateMessage.new(JSON.parse(request.body))
    unprocessable!(message.errors.full_messages) unless message.valid?

    app = AppModel.where(guid: message.app_guid).first

    unprocessable_app! unless app && permission_queryer.can_read_from_space?(app.space.id, app.space.organization_id)
    unauthorized! unless permission_queryer.can_write_to_active_space?(app.space.id)
    suspended! unless permission_queryer.is_space_active?(app.space.id)

    if message.type != PackageModel::DOCKER_TYPE && app.docker?
      unprocessable_non_docker_package!
    elsif message.type != PackageModel::BITS_TYPE && app.buildpack?
      unprocessable_non_bits_package!
    end

    PackageCreate.create(message:, user_audit_info:)
  end

  def create_copy
    unprocessable!('Unable to copy package when an image registry is used to store packages') if VCAP::CloudController::Config.config.package_image_registry_configured?

    app_guid = JSON.parse(request.body).deep_symbolize_keys.dig(:relationships, :app, :data, :guid)
    destination_app = AppModel.where(guid: app_guid).first

    unprocessable_app! unless destination_app && permission_queryer.can_read_from_space?(destination_app.space.id, destination_app.space.organization_id)
    unauthorized! unless permission_queryer.can_write_to_active_space?(destination_app.space.id)
    suspended! unless permission_queryer.is_space_active?(destination_app.space.id)

    source_package = PackageModel.where(guid: hashed_params[:source_guid]).first

    unprocessable_source_package! unless source_package && permission_queryer.can_read_from_space?(source_package.space.id, source_package.space.organization_id)
    unauthorized! unless permission_queryer.can_write_to_active_space?(source_package.space.id)
    suspended! unless permission_queryer.is_space_active?(source_package.space.id)

    PackageCopy.new.copy(
      destination_app_guid: app_guid,
      source_package: source_package,
      user_audit_info: user_audit_info
    )
  end

  def package_not_found!
    resource_not_found!(:package)
  end

  def bits_already_uploaded!
    raise CloudController::Errors::ApiError.new_from_details('PackageBitsAlreadyUploaded')
  end

  def send_package_blob(package)
    package_blobstore = CloudController::DependencyLocator.instance.package_blobstore
    BlobDispatcher.new(blobstore: package_blobstore, controller: self).send_or_redirect(guid: package.guid)
  end

  def unprocessable_non_bits_package!
    unprocessable!('Cannot create Docker package for a buildpack app.')
  end

  def unprocessable_non_docker_package!
    unprocessable!('Cannot create bits package for a Docker app.')
  end

  def unprocessable_non_docker_package_update!
    unprocessable!('Cannot update Docker credentials for a buildpack app.')
  end

  def unprocessable_app!
    unprocessable!('App is invalid. Ensure it exists and you have access to it.')
  end

  def unprocessable_source_package!
    unprocessable!('Source package is invalid. Ensure it exists and you have access to it.')
  end
end
