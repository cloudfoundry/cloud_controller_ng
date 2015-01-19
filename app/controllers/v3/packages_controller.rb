require 'presenters/v3/package_presenter'
require 'handlers/packages_handler'

module VCAP::CloudController
  class PackagesController < RestController::BaseController
    def self.dependencies
      [:packages_handler, :package_presenter, :apps_handler]
    end

    def inject_dependencies(dependencies)
      @packages_handler = dependencies[:packages_handler]
      @package_presenter = dependencies[:package_presenter]
      @apps_handler = dependencies[:apps_handler]
    end

    post '/v3/apps/:guid/packages', :create
    def create(app_guid)
      app = @apps_handler.show(app_guid, @access_context)
      app_not_found! if app.nil?

      message = PackageCreateMessage.create_from_http_request(app.space_guid, body)
      valid, errors = message.validate
      unprocessable!(errors.join(', ')) if !valid

      package = @packages_handler.create(message, @access_context)
      package_json = @package_presenter.present_json(package)

      [HTTP::CREATED, package_json]
    rescue PackagesHandler::Unauthorized
      unauthorized!
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
      app_not_found!
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
      package = @packages_handler.delete(package_guid, @access_context)
      package_not_found! unless package
      [HTTP::NO_CONTENT]
    rescue PackagesHandler::Unauthorized
      unauthorized!
    end

    private

    def package_not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'Package not found')
    end

    def app_not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'App not found')
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
