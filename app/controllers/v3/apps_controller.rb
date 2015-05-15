require 'presenters/v3/app_presenter'
require 'cloud_controller/paging/pagination_options'
require 'queries/app_delete_fetcher'
require 'queries/app_fetcher'
require 'queries/app_list_fetcher'
require 'queries/process_list_fetcher'
require 'actions/app_delete'
require 'actions/app_update'
require 'actions/app_start'
require 'actions/app_stop'
require 'actions/app_create'
require 'queries/assign_current_droplet_fetcher'
require 'actions/set_current_droplet'
require 'messages/app_create_message'

module VCAP::CloudController
  class AppsV3Controller < RestController::BaseController
    class InvalidParam < StandardError; end

    def self.dependencies
      [:app_presenter]
    end

    def inject_dependencies(dependencies)
      @app_presenter = dependencies[:app_presenter]
    end

    get '/v3/apps', :list
    def list
      check_read_permissions!
      validate_allowed_params(params)

      pagination_options = PaginationOptions.from_params(params)
      facets = params.slice('guids', 'space_guids', 'organization_guids', 'names')

      if membership.admin?
        paginated_apps = AppListFetcher.new.fetch_all(pagination_options, facets)
      else
        allowed_space_guids = membership.space_guids_for_roles([Membership::SPACE_DEVELOPER, Membership::SPACE_MANAGER, Membership::SPACE_AUDITOR, Membership::ORG_MANAGER])
        paginated_apps = AppListFetcher.new.fetch(pagination_options, facets, allowed_space_guids)
      end

      [HTTP::OK, @app_presenter.present_json_list(paginated_apps, facets)]
    rescue InvalidParam => e
      invalid_param!(e.message)
    end

    get '/v3/apps/:guid', :show
    def show(guid)
      check_read_permissions!

      app, space, org = AppFetcher.new.fetch(guid)

      app_not_found! if app.nil? || !can_read?(space.guid, org.guid)

      [HTTP::OK, @app_presenter.present_json(app)]
    end

    post '/v3/apps', :create
    def create
      check_write_permissions!

      request = parse_and_validate_json(body)
      message = AppCreateMessage.create_from_http_request(request)
      unprocessable!(message.errors.full_messages) unless message.valid?

      space_not_found! unless membership.has_any_roles?([Membership::SPACE_DEVELOPER], message.space_guid)

      app = AppCreate.new(current_user, current_user_email).create(message)

      [HTTP::CREATED, @app_presenter.present_json(app)]
    rescue AppCreate::InvalidApp => e
      unprocessable!(e.message)
    end

    patch '/v3/apps/:guid', :update
    def update(guid)
      check_write_permissions!
      message = parse_and_validate_json(body)

      app, space, org = AppFetcher.new.fetch(guid)

      app_not_found! if app.nil? || !can_read?(space.guid, org.guid)
      unauthorized! unless can_update?(space.guid)

      app = AppUpdate.new(current_user, current_user_email).update(app, message)

      [HTTP::OK, @app_presenter.present_json(app)]
    rescue AppUpdate::DropletNotFound
      droplet_not_found!
    rescue AppUpdate::InvalidApp => e
      unprocessable!(e.message)
    end

    delete '/v3/apps/:guid', :delete
    def delete(guid)
      check_write_permissions!

      app_delete_fetcher = AppDeleteFetcher.new
      app, space, org    = app_delete_fetcher.fetch(guid)

      app_not_found! if app.nil? || !can_read?(space.guid, org.guid)
      unauthorized! unless can_delete?(space.guid)

      AppDelete.new(current_user.guid, current_user_email).delete(app)

      [HTTP::NO_CONTENT]
    end

    put '/v3/apps/:guid/start', :start
    def start(guid)
      check_write_permissions!

      app, space, org = AppFetcher.new.fetch(guid)
      app_not_found! if app.nil? || !can_read?(space.guid, org.guid)
      unauthorized! unless can_start?(space.guid)

      AppStart.new(current_user, current_user_email).start(app)
      [HTTP::OK, @app_presenter.present_json(app)]
    rescue AppStart::DropletNotFound
      droplet_not_found!
    rescue AppStart::InvalidApp => e
      unprocessable!(e.message)
    end

    put '/v3/apps/:guid/stop', :stop
    def stop(guid)
      check_write_permissions!

      app, space, org = AppFetcher.new.fetch(guid)
      app_not_found! if app.nil? || !can_read?(space.guid, org.guid)
      unauthorized! unless can_stop?(space.guid)

      AppStop.new(current_user, current_user_email).stop(app)
      [HTTP::OK, @app_presenter.present_json(app)]
    rescue AppStop::InvalidApp => e
      unprocessable!(e.message)
    end

    get '/v3/apps/:guid/env', :env
    def env(guid)
      check_read_permissions!

      app, space, org = AppFetcher.new.fetch(guid)
      app_not_found! if app.nil? || !can_read?(space.guid, org.guid)
      unauthorized! unless can_read_envs?(space.guid)

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

    put '/v3/apps/:guid/current_droplet', :assign_current_droplet
    def assign_current_droplet(app_guid)
      check_write_permissions!

      droplet_guid = parse_and_validate_json(body)['desired_droplet_guid']

      app, space, org, droplet = AssignCurrentDropletFetcher.new.fetch(app_guid, droplet_guid)

      app_not_found! if app.nil? || !can_read?(space.guid, org.guid)
      unauthorized! unless can_update?(space.guid)
      unprocessable!('Stop the app before changing droplet') if app.desired_state != 'STOPPED'

      droplet_not_found! if droplet.nil?

      app = SetCurrentDroplet.new(current_user, current_user_email).update_to(app, droplet)

      [HTTP::OK, @app_presenter.present_json(app)]
    end

    def membership
      @membership ||= Membership.new(current_user)
    end

    private

    def can_read?(space_guid, org_guid)
      membership.has_any_roles?([Membership::SPACE_DEVELOPER,
                                 Membership::SPACE_MANAGER,
                                 Membership::SPACE_AUDITOR,
                                 Membership::ORG_MANAGER], space_guid, org_guid)
    end

    def can_update?(space_guid)
      membership.has_any_roles?([Membership::SPACE_DEVELOPER], space_guid)
    end

    def can_delete?(space_guid)
      can_update?(space_guid)
    end

    def can_start?(space_guid)
      can_update?(space_guid)
    end

    def can_stop?(space_guid)
      can_update?(space_guid)
    end

    def can_read_envs?(space_guid)
      can_update?(space_guid)
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
        raise InvalidParam.new("Unknown query param #{key}") if validator.nil?
        raise InvalidParam.new("Invalid type for param #{key}") if !validator.call(value)
      end
    end

    def unable_to_perform!(msg, details)
      raise VCAP::Errors::ApiError.new_from_details('UnableToPerform', msg, details)
    end

    def droplet_not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'Droplet not found')
    end

    def space_not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'Space not found')
    end

    def app_not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'App not found')
    end

    def unauthorized!
      raise VCAP::Errors::ApiError.new_from_details('NotAuthorized')
    end

    def unprocessable!(message)
      raise VCAP::Errors::ApiError.new_from_details('UnprocessableEntity', message)
    end
  end
end
