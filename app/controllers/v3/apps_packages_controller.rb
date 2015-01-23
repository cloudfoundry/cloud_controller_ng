require 'presenters/v3/package_presenter'
require 'handlers/packages_handler'
require 'handlers/apps_handler'
require 'cloud_controller/paging/pagination_options'

module VCAP::CloudController
  class AppsPackagesController < RestController::BaseController
    def self.dependencies
      [:packages_handler, :package_presenter, :apps_handler]
    end

    def inject_dependencies(dependencies)
      @app_handler       = dependencies[:apps_handler]
      @package_handler   = dependencies[:packages_handler]
      @package_presenter = dependencies[:package_presenter]
    end

    get '/v3/apps/:guid/packages', :list_packages
    def list_packages(guid)
      app = @app_handler.show(guid, @access_context)
      app_not_found! if app.nil?

      pagination_options = PaginationOptions.from_params(params)
      paginated_result   = @package_handler.list(pagination_options, @access_context, app_guid: app.guid)

      [HTTP::OK, @package_presenter.present_json_list(paginated_result, "/v3/apps/#{guid}/packages")]
    end

    post '/v3/apps/:guid/packages', :create
    def create(app_guid)
      app = @app_handler.show(app_guid, @access_context)
      app_not_found! if app.nil?

      message = PackageCreateMessage.create_from_http_request(app.space_guid, body)
      valid, errors = message.validate
      unprocessable!(errors.join(', ')) if !valid

      package = @package_handler.create(message, @access_context)
      package = @app_handler.add_package(app, package, @access_context)

      [HTTP::CREATED, @package_presenter.present_json(package)]
    rescue PackagesHandler::Unauthorized
      unauthorized!
    rescue AppsHandler::Unauthorized
      unauthorized!
    end

    private

    def app_not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'App not found')
    end

    def unprocessable!(message)
      raise VCAP::Errors::ApiError.new_from_details('UnprocessableEntity', message)
    end

    def unauthorized!
      raise VCAP::Errors::ApiError.new_from_details('NotAuthorized')
    end
  end
end
