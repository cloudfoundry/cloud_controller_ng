require 'presenters/v3/package_presenter'
require 'handlers/packages_handler'

module VCAP::CloudController
  class PackagesController < RestController::BaseController
    def self.dependencies
      [ :packages_handler, :package_presenter ]
    end

    def inject_dependencies(dependencies)
      @packages_handler = dependencies[:packages_handler]
      @package_presenter = dependencies[:package_presenter]
    end

    post '/v3/apps/:guid/packages', :create
    def create(app_guid)
      message = PackageCreateMessage.new(app_guid, params)
      valid, errors = message.validate
      unprocessable!(errors.join(', ')) if !valid

      package = @packages_handler.create(message, @access_context)
      package_json = @package_presenter.present_json(package)

      [HTTP::CREATED, package_json]
    rescue PackagesHandler::Unauthorized
      unauthorized!
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

    private

    def package_not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'Package not found')
    end

    def bad_request!(message)
      raise VCAP::Errors::ApiError.new_from_details('MessageParseError', message)
    end

    def unauthorized!
      raise VCAP::Errors::ApiError.new_from_details('NotAuthorized')
    end

    def unprocessable!(message)
      raise VCAP::Errors::ApiError.new_from_details('UnprocessableEntity', message)
    end
  end
end
