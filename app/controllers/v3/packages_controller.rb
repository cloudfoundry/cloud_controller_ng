require 'presenters/v3/package_presenter'
require 'presenters/v3/droplet_presenter'
require 'handlers/packages_handler'
require 'handlers/droplets_handler'

module VCAP::CloudController
  class PackagesController < RestController::BaseController
    def self.dependencies
      [:packages_handler, :package_presenter, :droplets_handler, :droplet_presenter, :apps_handler]
    end

    def inject_dependencies(dependencies)
      @packages_handler = dependencies[:packages_handler]
      @package_presenter = dependencies[:package_presenter]
      @droplets_handler = dependencies[:droplets_handler]
      @droplet_presenter = dependencies[:droplet_presenter]
      @apps_handler = dependencies[:apps_handler]
    end

    get '/v3/packages', :list
    def list
      pagination_options = PaginationOptions.from_params(params)
      paginated_result   = @packages_handler.list(pagination_options, @access_context)
      packages_json      = @package_presenter.present_json_list(paginated_result, '/v3/packages')
      [HTTP::OK, packages_json]
    end

    post '/v3/packages/:guid/upload', :upload
    def upload(package_guid)
      message = PackageUploadMessage.new(package_guid, params)
      valid, error = message.validate
      unprocessable!(error) if !valid

      package = @packages_handler.upload(message, @access_context)
      package_json = @package_presenter.present_json(package)

      [HTTP::CREATED, package_json]
    rescue PackagesHandler::InvalidPackageType => e
      invalid_request!(e.message)
    rescue PackagesHandler::SpaceNotFound
      space_not_found!
    rescue PackagesHandler::PackageNotFound
      package_not_found!
    rescue PackagesHandler::Unauthorized
      unauthorized!
    rescue PackagesHandler::BitsAlreadyUploaded
      bits_already_uploaded!
    end

    get '/v3/packages/:guid', :show
    def show(package_guid)
      package = @packages_handler.show(package_guid, @access_context)
      package_not_found! if package.nil?

      package_json = @package_presenter.present_json(package)
      [HTTP::OK, package_json]
    rescue PackagesHandler::Unauthorized
      unauthorized!
    end

    delete '/v3/packages/:guid', :delete
    def delete(package_guid)
      package = @packages_handler.delete(@access_context, filter: { guid: package_guid }).first
      package_not_found! unless package
      [HTTP::NO_CONTENT]
    rescue PackagesHandler::Unauthorized
      unauthorized!
    end

    post '/v3/packages/:guid/droplets', :stage
    def stage(package_guid)
      staging_message = StagingMessage.create_from_http_request(package_guid, body)
      valid, error = staging_message.validate
      unprocessable!(error) if !valid

      droplet = @droplets_handler.create(staging_message, @access_context)

      [HTTP::CREATED, @droplet_presenter.present_json(droplet)]
    rescue DropletsHandler::BuildpackNotFound
      buildpack_not_found!
    rescue DropletsHandler::PackageNotFound
      package_not_found!
    rescue DropletsHandler::SpaceNotFound
      space_not_found!
    rescue DropletsHandler::Unauthorized
      unauthorized!
    rescue DropletsHandler::InvalidRequest => e
      invalid_request!(e.message)
    end

    private

    def package_not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'Package not found')
    end

    def space_not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'Space not found')
    end

    def buildpack_not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'Buildpack not found')
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
  end
end
