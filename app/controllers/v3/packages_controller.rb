require 'presenters/v3/package_presenter'
require 'queries/package_list_fetcher'
require 'actions/package_delete'
require 'actions/package_upload'
require 'actions/package_create'
require 'actions/package_copy'
require 'messages/package_create_message'
require 'messages/package_upload_message'
require 'messages/packages_list_message'
require 'controllers/v3/mixins/app_subresource'

class PackagesController < ApplicationController
  include AppSubresource

  before_action :check_read_permissions!, only: [:index, :show, :download]

  def index
    message = PackagesListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    pagination_options = PaginationOptions.from_params(query_params)
    invalid_param!(pagination_options.errors.full_messages) unless pagination_options.valid?

    if app_nested?
      app, paginated_result = list_fetcher.fetch_for_app(app_guid: params[:app_guid], pagination_options: pagination_options)
      app_not_found! unless app && can_read?(app.space.guid, app.organization.guid)
    else
      paginated_result = if roles.admin?
                           list_fetcher.fetch_all(pagination_options: pagination_options)
                         else
                           list_fetcher.fetch_for_spaces(pagination_options: pagination_options, space_guids: readable_space_guids)
                         end
    end

    render status: :ok, json: package_presenter.present_json_list(paginated_result, base_url(resource: 'packages'))
  end

  def upload
    FeatureFlag.raise_unless_enabled!('app_bits_upload') unless roles.admin?

    message = PackageUploadMessage.create_from_params(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    package = PackageModel.where(guid: params[:guid]).eager(:space, space: :organization).eager(:docker_data).all.first
    package_not_found! unless package && can_read?(package.space.guid, package.space.organization.guid)
    unauthorized! unless can_upload?(package.space.guid)

    unprocessable!('Package type must be bits.') unless package.type == 'bits'
    bits_already_uploaded! if package.state != PackageModel::CREATED_STATE

    begin
      PackageUpload.new.upload(message, package, configuration)
    rescue PackageUpload::InvalidPackage => e
      unprocessable!(e.message)
    end

    render status: :ok, json: package_presenter.present_json(package)
  end

  def download
    package = PackageModel.where(guid: params[:guid]).eager(:space, space: :organization).eager(:docker_data).all.first
    package_not_found! unless package && can_read?(package.space.guid, package.space.organization.guid)

    unprocessable!('Package type must be bits.') unless package.type == 'bits'
    unprocessable!('Package has no bits to download.') unless package.state == 'READY'

    blob = blobstore.blob(package.guid)
    BlobDispatcher.new(blob_sender: blob_sender, controller: self).send_or_redirect(local: blobstore.local?, blob: blob)
  end

  def show
    package = PackageModel.where(guid: params[:guid]).eager(:space, space: :organization).eager(:docker_data).all.first
    package_not_found! unless package && can_read?(package.space.guid, package.space.organization.guid)

    render status: :ok, json: package_presenter.present_json(package)
  end

  def destroy
    package = PackageModel.where(guid: params[:guid]).eager(:space, space: :organization).all.first
    package_not_found! unless package && can_read?(package.space.guid, package.space.organization.guid)
    unauthorized! unless can_delete?(package.space.guid)

    PackageDelete.new.delete(package)

    head :no_content
  end

  def create
    if params[:source_package_guid]
      create_copy
    else
      create_new
    end
  end

  def create_new
    message = PackageCreateMessage.create_from_http_request(params[:app_guid], params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    app = AppModel.where(guid: params[:app_guid]).eager(:space, :organization).all.first
    app_not_found! unless app && can_read?(app.space.guid, app.organization.guid)
    unauthorized! unless can_create?(app.space.guid)

    package = PackageCreate.new(current_user, current_user_email).create(message)

    render status: :created, json: PackagePresenter.new.present_json(package)
  rescue PackageCreate::InvalidPackage => e
    unprocessable!(e.message)
  end

  def create_copy
    destination_app = AppModel.where(guid: params[:app_guid]).eager(:space, :organization).all.first
    app_not_found! unless destination_app && can_read?(destination_app.space.guid, destination_app.organization.guid)
    unauthorized! unless can_create?(destination_app.space.guid)

    source_package = PackageModel.where(guid: params[:source_package_guid]).eager(:app, :space, space: :organization).eager(:docker_data).all.first
    package_not_found! unless source_package && can_read?(source_package.space.guid, source_package.space.organization.guid)
    unauthorized! unless can_create?(source_package.space.guid)

    package = PackageCopy.new.copy(params[:app_guid], source_package)

    render status: :created, json: PackagePresenter.new.present_json(package)
  rescue PackageCopy::InvalidPackage => e
    unprocessable!(e.message)
  end

  private

  def can_create?(space_guid)
    roles.admin? || membership.has_any_roles?([Membership::SPACE_DEVELOPER], space_guid)
  end
  alias_method :can_delete?, :can_create?
  alias_method :can_upload?, :can_create?

  def package_not_found!
    resource_not_found!(:package)
  end

  def bits_already_uploaded!
    raise VCAP::Errors::ApiError.new_from_details('PackageBitsAlreadyUploaded')
  end

  def package_presenter
    @package_presenter ||= PackagePresenter.new
  end

  def blob_sender
    CloudController::DependencyLocator.instance.blob_sender
  end

  def blobstore
    CloudController::DependencyLocator.instance.package_blobstore
  end

  def list_fetcher
    PackageListFetcher.new
  end
end
