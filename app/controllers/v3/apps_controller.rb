require 'presenters/v3/app_presenter'
require 'handlers/processes_handler'
require 'handlers/apps_handler'

module VCAP::CloudController
  class AppsV3Controller < RestController::BaseController
    def self.dependencies
      [ :processes_handler, :process_presenter, :apps_handler, :app_presenter ]
    end

    def inject_dependencies(dependencies)
      @process_handler = dependencies[:processes_handler]
      @app_handler = dependencies[:apps_handler]
      @app_presenter = dependencies[:app_presenter]
      @process_presenter = dependencies[:process_presenter]
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
    end

    patch '/v3/apps/:guid', :update
    def update(guid)
      message = AppUpdateMessage.create_from_http_request(guid, body)
      bad_request!(message.error) if message.error

      app = @app_handler.update(message, @access_context)
      app_not_found! if app.nil?

      [HTTP::OK, @app_presenter.present_json(app)]
    rescue AppsHandler::Unauthorized
      unauthorized!
    end

    delete '/v3/apps/:guid', :delete
    def delete(guid)
      deleted = @app_handler.delete(guid, @access_context)
      app_not_found! unless deleted

      [HTTP::NO_CONTENT]
    rescue AppsHandler::DeleteWithProcesses
      raise VCAP::Errors::ApiError.new_from_details('UnableToPerform', 'App deletion', 'Has child processes')
    end

    ###
    ### Processes
    ###

    get '/v3/apps/:guid/processes', :list_processes
    def list_processes(guid)
      app = @app_handler.show(guid, @access_context)
      app_not_found! if app.nil?

      [HTTP::OK, @process_presenter.present_json_list(app.processes)]
    end

    put '/v3/apps/:guid/processes', :add_process
    def add_process(guid)
      opts = MultiJson.load(body)

      app = @app_handler.show(guid, @access_context)
      app_not_found! if app.nil?

      process = @process_handler.show(opts['process_guid'], @access_context)
      process_not_found! if process.nil?

      @app_handler.add_process(app, process, @access_context)

      [HTTP::NO_CONTENT]
    rescue MultiJson::ParseError => e
      raise VCAP::Errors::ApiError.new_from_details('MessageParseError', e.message)
    rescue AppsHandler::DuplicateProcessType
      invalid_process_type!(process.type)
    rescue AppsHandler::Unauthorized
      app_not_found!
    end

    delete '/v3/apps/:guid/processes', :remove_process
    def remove_process(guid)
      opts = MultiJson.load(body)

      app = @app_handler.show(guid, @access_context)
      app_not_found! if app.nil?

      process = @process_handler.show(opts['process_guid'], @access_context)
      process_not_found! if process.nil?

      @app_handler.remove_process(app, process, @access_context)

      [HTTP::NO_CONTENT]
    rescue MultiJson::ParseError => e
      raise VCAP::Errors::ApiError.new_from_details('MessageParseError', e.message)
    rescue AppsHandler::Unauthorized
      app_not_found!
    end
  end

  private

  def app_not_found!
    raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'App not found')
  end

  def process_not_found!
    raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'Process not found')
  end

  def invalid_process_type!(type)
    raise VCAP::Errors::ApiError.new_from_details('ProcessInvalid', "Type '#{type}' is already in use")
  end

  def bad_request!(message)
    raise VCAP::Errors::ApiError.new_from_details('MessageParseError', message)
  end

  def unauthorized!
    raise VCAP::Errors::ApiError.new_from_details('NotAuthorized')
  end
end
