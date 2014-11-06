require 'presenters/v3/app_presenter'
require 'repositories/process_repository'
require 'repositories/app_repository'
require 'handlers/processes_handler'

module VCAP::CloudController
  class AppsV3Controller < RestController::BaseController
    def inject_dependencies(dependencies)
      @process_repository = dependencies[:process_repository]
      @app_repository =  dependencies[:app_repository]
    end

    get '/v3/apps/:guid', :show
    def show(guid)
      app = @app_repository.find_by_guid(guid)

      if app.nil? || @access_context.cannot?(:read, app)
        raise VCAP::Errors::ApiError.new_from_details('NotFound')
      end

      presenter = AppPresenter.new(app)
      [HTTP::OK, presenter.present_json]
    end

    post '/v3/apps', :create
    def create
      creation_opts = MultiJson.load(body).symbolize_keys
      app = @app_repository.new_app(creation_opts)

      if @access_context.cannot?(:create, app)
        raise VCAP::Errors::ApiError.new_from_details('NotAuthorized')
      end

      app = @app_repository.persist!(app)

      presenter = AppPresenter.new(app)
      [HTTP::CREATED, presenter.present_json]
    rescue MultiJson::ParseError => e
      raise VCAP::Errors::ApiError.new_from_details('MessageParseError', e.message)
    end

    put '/v3/apps/:guid/processes', :add_process
    def add_process(guid)
      app = @app_repository.find_by_guid(guid)

      if app.nil? || @access_context.cannot?(:update, app)
        raise VCAP::Errors::ApiError.new_from_details('NotFound')
      end

      opts = MultiJson.load(body).symbolize_keys
      process = @process_repository.find_by_guid(opts[:process_guid])
      @app_repository.add_process!(app, process)

      [HTTP::OK, {}]
    rescue MultiJson::ParseError => e
      raise VCAP::Errors::ApiError.new_from_details('MessageParseError', e.message)
    rescue AppRepository::InvalidProcessAssociation => e
      raise VCAP::Errors::ApiError.new_from_details('NotFound')
    end

    delete '/v3/apps/:guid', :delete
    def delete(guid)
      @app_repository.find_by_guid_for_update(guid) do |app|

        if app.nil? || @access_context.cannot?(:delete, app)
          raise VCAP::Errors::ApiError.new_from_details('NotFound')
        end

        if app.processes.any?
          raise VCAP::Errors::ApiError.new_from_details('Conflict', 'Has child processes')
        end

        @app_repository.delete(app)
      end
      [HTTP::NO_CONTENT]
    end
  end
end
