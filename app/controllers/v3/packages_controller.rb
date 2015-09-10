require 'presenters/v3/package_presenter'
require 'presenters/v3/droplet_presenter'
require 'queries/package_list_fetcher'
require 'queries/package_delete_fetcher'
require 'actions/package_stage_action'
require 'actions/package_delete'
require 'actions/package_download'
require 'actions/package_upload'
require 'messages/package_upload_message'
require 'messages/droplet_create_message'

module VCAP::CloudController
  class PackagesController < RestController::BaseController
    def self.dependencies
      [:package_presenter, :droplet_presenter, :stagers]
    end

    def inject_dependencies(dependencies)
      @package_presenter = dependencies[:package_presenter]
      @stagers           = dependencies[:stagers]
      @droplet_presenter = dependencies[:droplet_presenter]
    end

    get '/v3/packages', :list
    def list
      check_read_permissions!

      pagination_options = PaginationOptions.from_params(params)
      invalid_param!(pagination_options.errors.full_messages) unless pagination_options.valid?
      invalid_param!("Unknown query param(s) '#{params.keys.join("', '")}'") if params.any?

      if membership.admin?
        paginated_result = PackageListFetcher.new.fetch_all(pagination_options)
      else
        space_guids = membership.space_guids_for_roles(
          [Membership::SPACE_DEVELOPER,
           Membership::SPACE_MANAGER,
           Membership::SPACE_AUDITOR,
           Membership::ORG_MANAGER])
        paginated_result = PackageListFetcher.new.fetch(pagination_options, space_guids)
      end

      [HTTP::OK, @package_presenter.present_json_list(paginated_result, '/v3/packages')]
    end

    post '/v3/packages/:guid/upload', :upload
    def upload(package_guid)
      check_write_permissions!

      FeatureFlag.raise_unless_enabled!('app_bits_upload') unless membership.admin?

      message = PackageUploadMessage.create_from_params(params)
      unprocessable!(message.errors.full_messages) unless message.valid?

      package = PackageModel.where(guid: package_guid).eager(:space, space: :organization).all.first
      package_not_found! if package.nil? || !can_read?(package.space.guid, package.space.organization.guid)
      unauthorized! unless can_upload?(package.space.guid)

      unprocessable!('Package type must be bits.') unless package.type == 'bits'
      bits_already_uploaded! if package.state != PackageModel::CREATED_STATE

      PackageUpload.new.upload(message, package, config)

      [HTTP::OK, @package_presenter.present_json(package)]
    rescue PackageUpload::InvalidPackage => e
      unprocessable!(e.message)
    end

    get '/v3/packages/:guid/download', :download
    def download(package_guid)
      check_read_permissions!

      package = PackageModel.where(guid: package_guid).eager(:space, space: :organization).all.first
      package_not_found! if package.nil? || !can_read?(package.space.guid, package.space.organization.guid)

      unprocessable!('Package type must be bits.') unless package.type == 'bits'
      unprocessable!('Package has no bits to download.') unless package.state == 'READY'

      file_path_for_download, url_for_response = PackageDownload.new.download(package)
      if file_path_for_download
        send_file(file_path_for_download)
      elsif url_for_response
        return [HTTP::FOUND, { 'Location' => url_for_response }, nil]
      end
    end

    get '/v3/packages/:guid', :show
    def show(guid)
      check_read_permissions!
      package = PackageModel.where(guid: guid).eager(:space, space: :organization).all.first
      package_not_found! if package.nil? || !can_read?(package.space.guid, package.space.organization.guid)

      [HTTP::OK, @package_presenter.present_json(package)]
    end

    delete '/v3/packages/:guid', :delete
    def delete(guid)
      check_write_permissions!

      package_delete_fetcher = PackageDeleteFetcher.new
      package, space, org    = package_delete_fetcher.fetch(guid)
      package_not_found! if package.nil? || !can_read?(space.guid, org.guid)
      unauthorized! unless can_delete?(space.guid)

      PackageDelete.new.delete(package)

      [HTTP::NO_CONTENT]
    end

    post '/v3/packages/:guid/droplets', :stage
    def stage(package_guid)
      check_write_permissions!

      request = parse_and_validate_json(body)
      staging_message = DropletCreateMessage.create_from_http_request(request)
      unprocessable!(staging_message.errors.full_messages) unless staging_message.valid?

      package = PackageModel.where(guid: package_guid).eager(:app, :space, space: :organization).all.first
      package_not_found! if package.nil? || !can_read?(package.space.guid, package.space.organization.guid)

      unauthorized! unless can_stage?(package.space.guid)

      buildpack_to_use    = staging_message.buildpack.nil? ? package.app.buildpack : staging_message.buildpack
      buildpack_info = BuildpackRequestValidator.new(buildpack: buildpack_to_use)
      unprocessable!(buildpack_info.errors.full_messages) unless buildpack_info.valid?

      droplet = PackageStageAction.new.stage(package, buildpack_info, staging_message, @stagers)

      [HTTP::CREATED, @droplet_presenter.present_json(droplet)]
    rescue PackageStageAction::InvalidPackage => e
      invalid_request!(e.message)
    rescue PackageStageAction::SpaceQuotaExceeded
      unable_to_perform!('Staging request', "space's memory limit exceeded")
    rescue PackageStageAction::OrgQuotaExceeded
      unable_to_perform!('Staging request', "organization's memory limit exceeded")
    rescue PackageStageAction::DiskLimitExceeded
      unable_to_perform!('Staging request', 'disk limit exceeded')
    end

    def membership
      @membership ||= Membership.new(current_user)
    end

    private

    def can_read?(space_guid, org_guid)
      membership.has_any_roles?(
        [Membership::SPACE_DEVELOPER,
         Membership::SPACE_MANAGER,
         Membership::SPACE_AUDITOR,
         Membership::ORG_MANAGER],
        space_guid, org_guid)
    end

    def can_stage?(space_guid)
      membership.has_any_roles?([Membership::SPACE_DEVELOPER], space_guid)
    end

    def can_delete?(space_guid)
      membership.has_any_roles?([Membership::SPACE_DEVELOPER], space_guid)
    end

    def can_upload?(space_guid)
      membership.has_any_roles?([Membership::SPACE_DEVELOPER], space_guid)
    end

    def package_not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'Package not found')
    end

    def buildpack_not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'Buildpack not found')
    end

    def app_not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'App not found ')
    end

    def unauthorized!
      raise VCAP::Errors::ApiError.new_from_details('NotAuthorized')
    end

    def bits_already_uploaded!
      raise VCAP::Errors::ApiError.new_from_details('PackageBitsAlreadyUploaded')
    end

    def unprocessable!(message)
      raise VCAP::Errors::ApiError.new_from_details('UnprocessableEntity', message)
    end

    def invalid_request!(message)
      raise VCAP::Errors::ApiError.new_from_details('InvalidRequest', message)
    end

    def unable_to_perform!(operation, message)
      raise VCAP::Errors::ApiError.new_from_details('UnableToPerform', operation, message)
    end
  end
end
