require 'presenters/v3/package_presenter'
require 'presenters/v3/droplet_presenter'
require 'queries/package_list_fetcher'
require 'actions/package_stage_action'
require 'actions/package_delete'
require 'actions/package_download'
require 'actions/package_upload'
require 'messages/package_upload_message'
require 'messages/droplet_create_message'
require 'messages/packages_list_message'
require 'builders/droplet_stage_request_builder'

class PackagesController < ApplicationController
  before_action :check_read_permissions!, only: [:index, :show, :download]

  def index
    message = PackagesListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    pagination_options = PaginationOptions.from_params(query_params)
    invalid_param!(pagination_options.errors.full_messages) unless pagination_options.valid?

    if roles.admin?
      paginated_result = PackageListFetcher.new.fetch_all(pagination_options)
    else
      space_guids = membership.space_guids_for_roles(
        [Membership::SPACE_DEVELOPER,
         Membership::SPACE_MANAGER,
         Membership::SPACE_AUDITOR,
         Membership::ORG_MANAGER])
      paginated_result = PackageListFetcher.new.fetch(pagination_options, space_guids)
    end

    render stats: :ok, json: package_presenter.present_json_list(paginated_result, '/v3/packages')
  end

  def upload
    FeatureFlag.raise_unless_enabled!('app_bits_upload') unless roles.admin?

    message = PackageUploadMessage.create_from_params(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    package = PackageModel.where(guid: params[:guid]).eager(:space, space: :organization).eager(:docker_data).all.first
    package_not_found! if package.nil? || !can_read?(package.space.guid, package.space.organization.guid)
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
    package_not_found! if package.nil? || !can_read?(package.space.guid, package.space.organization.guid)

    unprocessable!('Package type must be bits.') unless package.type == 'bits'
    unprocessable!('Package has no bits to download.') unless package.state == 'READY'

    file_path_for_download, url_for_response = PackageDownload.new.download(package)
    if file_path_for_download
      send_file(file_path_for_download)
    elsif url_for_response
      redirect_to url_for_response
    end
  end

  def show
    package = PackageModel.where(guid: params[:guid]).eager(:space, space: :organization).eager(:docker_data).all.first
    package_not_found! if package.nil? || !can_read?(package.space.guid, package.space.organization.guid)

    render status: :ok, json: package_presenter.present_json(package)
  end

  def destroy
    package = PackageModel.where(guid: params[:guid]).eager(:space, space: :organization).all.first
    package_not_found! if package.nil? || !can_read?(package.space.guid, package.space.organization.guid)
    unauthorized! unless can_delete?(package.space.guid)

    PackageDelete.new.delete(package)

    head :no_content
  end

  def stage
    package = PackageModel.where(guid: params[:guid]).eager(:app, :space, space: :organization).all.first
    package_not_found! if package.nil? || !can_read?(package.space.guid, package.space.organization.guid)

    app_lifecycle = package.app.lifecycle_data
    assembled_request  = DropletStageRequestBuilder.new.build(params[:body], app_lifecycle)
    staging_message = DropletCreateMessage.create_from_http_request(assembled_request)
    unprocessable!(staging_message.errors.full_messages) unless staging_message.valid?

    unauthorized! unless can_stage?(package.space.guid)

    buildpack_to_use = staging_message.requested_buildpack? ? staging_message.buildpack : package.app.lifecycle_data.buildpack
    buildpack_info = BuildpackRequestValidator.new(buildpack: buildpack_to_use)
    unprocessable!(buildpack_info.errors.full_messages) unless buildpack_info.valid?

    droplet = PackageStageAction.new.stage(package, buildpack_info, staging_message, stagers)

    render status: :created, json: droplet_presenter.present_json(droplet)
  rescue PackageStageAction::InvalidPackage => e
    invalid_request!(e.message)
  rescue PackageStageAction::SpaceQuotaExceeded
    unable_to_perform!('Staging request', "space's memory limit exceeded")
  rescue PackageStageAction::OrgQuotaExceeded
    unable_to_perform!('Staging request', "organization's memory limit exceeded")
  rescue PackageStageAction::DiskLimitExceeded
    unable_to_perform!('Staging request', 'disk limit exceeded')
  end

  private

  def can_read?(space_guid, org_guid)
    roles.admin? ||
    membership.has_any_roles?(
      [Membership::SPACE_DEVELOPER,
       Membership::SPACE_MANAGER,
       Membership::SPACE_AUDITOR,
       Membership::ORG_MANAGER],
      space_guid, org_guid)
  end

  def can_delete?(space_guid)
    roles.admin? || membership.has_any_roles?([Membership::SPACE_DEVELOPER], space_guid)
  end
  alias_method :can_stage?, :can_delete?
  alias_method :can_upload?, :can_delete?

  def package_not_found!
    raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'Package not found')
  end

  def bits_already_uploaded!
    raise VCAP::Errors::ApiError.new_from_details('PackageBitsAlreadyUploaded')
  end

  def unable_to_perform!(operation, message)
    raise VCAP::Errors::ApiError.new_from_details('UnableToPerform', operation, message)
  end

  def membership
    @membership ||= Membership.new(current_user)
  end

  def package_presenter
    @package_presenter ||= PackagePresenter.new
  end

  def droplet_presenter
    @droplet_presenter ||= DropletPresenter.new
  end

  def stagers
    CloudController::DependencyLocator.instance.stagers
  end
end
