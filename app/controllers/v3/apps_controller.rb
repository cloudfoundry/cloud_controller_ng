require 'presenters/v3/app_presenter'
require 'handlers/apps_handler'
require 'cloud_controller/paging/pagination_options'
require 'queries/app_delete_fetcher'
require 'actions/app_delete'
require 'actions/app_update'
require 'queries/app_fetcher'
require 'actions/app_start'
require 'actions/app_stop'

module VCAP::CloudController
  class AppsV3Controller < RestController::BaseController
    class InvalidParam < StandardError; end

    def self.dependencies
      [:apps_handler, :app_presenter]
    end

    def inject_dependencies(dependencies)
      @app_handler       = dependencies[:apps_handler]
      @app_presenter     = dependencies[:app_presenter]
    end

    get '/v3/apps', :list
    def list
      validate_allowed_params(params)

      pagination_options = PaginationOptions.from_params(params)
      facets = params.slice('guids', 'space_guids', 'organization_guids', 'names')
      paginated_result   = @app_handler.list(pagination_options, @access_context, facets)

      [HTTP::OK, @app_presenter.present_json_list(paginated_result, facets)]
    rescue InvalidParam => e
      invalid_param!(e.message)
    end

    get '/v3/apps/:guid', :show
    def show(guid)
      app = @app_handler.show(guid, @access_context)
      app_not_found! if app.nil?

      [HTTP::OK, @app_presenter.present_json(app)]
    end

    post '/v3/apps', :create
    def create
      message = AppCreateMessage.create_from_http_request(body)
      bad_request!(message.error) if message.error

      app = @app_handler.create(message, @access_context)

      [HTTP::CREATED, @app_presenter.present_json(app)]
    rescue AppsHandler::Unauthorized
      unauthorized!
    rescue AppsHandler::InvalidApp => e
      unprocessable!(e.message)
    end

    patch '/v3/apps/:guid', :update
    def update(guid)
      check_write_permissions!
      message = parse_and_validate_json(body)

      app = AppFetcher.new(current_user).fetch(guid)
      app_not_found! if app.nil?

      app = AppUpdate.update(app, message)

      [HTTP::OK, @app_presenter.present_json(app)]
    rescue AppUpdate::DropletNotFound
      droplet_not_found!
    rescue AppUpdate::InvalidApp => e
      unprocessable!(e.message)
    end

    delete '/v3/apps/:guid', :delete
    def delete(guid)
      check_write_permissions!

      app_delete_fetcher = AppDeleteFetcher.new(current_user)
      app_dataset        = app_delete_fetcher.fetch(guid)
      app_not_found! if app_dataset.empty?

      AppDelete.new(current_user, current_user_email).delete(app_dataset)

      [HTTP::NO_CONTENT]
    end

    put '/v3/apps/:guid/start', :start
    def start(guid)
      check_write_permissions!

      app = AppFetcher.new(current_user).fetch(guid)
      app_not_found! if app.nil?

      AppStart.new.start(app)
      [HTTP::OK, @app_presenter.present_json(app)]
    rescue AppStart::DropletNotFound
      droplet_not_found!
    end

    put '/v3/apps/:guid/stop', :stop
    def stop(guid)
      check_write_permissions!

      app = AppFetcher.new(current_user).fetch(guid)
      app_not_found! if app.nil?

      AppStop.new.stop(app)
      [HTTP::OK, @app_presenter.present_json(app)]
    end

    get '/v3/apps/:guid/env', :env
    def env(guid)
      check_read_permissions!

      app = AppFetcher.new(current_user).fetch(guid)
      app_not_found! if app.nil?

      env_vars = app.environment_variables
      uris = app.routes.map(&:fqdn)
      vcap_application = {
        'VCAP_APPLICATION' => {
          limits: {
            fds: Config.config[:instance_file_descriptor_limit] || 16384,
          },
          application_name: app.name,
          application_uris: uris,
          name: app.name,
          space_name: app.space.name,
          space_id: app.space.guid,
          uris: uris,
          users: nil
        }
      }

      [
        HTTP::OK,
        {
          'environment_variables' => env_vars,
          'staging_env_json' => EnvironmentVariableGroup.staging.environment_json,
          'running_env_json' => EnvironmentVariableGroup.running.environment_json,
          'application_env_json' => vcap_application
        }.to_json
      ]
    end

    private

    def parse_and_validate_json(body)
      parsed = body && MultiJson.load(body)
      raise MultiJson::ParseError.new('invalid request body') unless parsed.is_a?(Hash)
      parsed
    rescue MultiJson::ParseError => e
      bad_request!(e.message)
    end

    def validate_allowed_params(params)
      schema = {
        'names' => ->(v) { v.is_a? Array },
        'guids' => ->(v) { v.is_a? Array },
        'organization_guids' => ->(v) { v.is_a? Array },
        'space_guids' => ->(v) { v.is_a? Array },
        'page' => ->(v) { v.to_i > 0 },
        'per_page' => ->(v) { v.to_i > 0 },
        'order_by' => ->(v) { %w(created_at updated_at).include?(v) },
        'order_direction' => ->(v) { %w(asc desc).include?(v) }
      }
      params.each do |key, value|
        validator = schema[key]
        raise InvalidParam.new("Unknow query param #{key}") if validator.nil?
        raise InvalidParam.new("Invalid type for param #{key}") if !validator.call(value)
      end
    end

    def unable_to_perform!(msg, details)
      raise VCAP::Errors::ApiError.new_from_details('UnableToPerform', msg, details)
    end

    def droplet_not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'Droplet not found')
    end

    def app_not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'App not found')
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

    def invalid_param!(message)
      raise VCAP::Errors::ApiError.new_from_details('BadQueryParameter', message)
    end
  end
end
