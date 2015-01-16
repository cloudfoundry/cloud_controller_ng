require 'presenters/v3/app_presenter'
require 'handlers/processes_handler'
require 'handlers/apps_handler'
require 'cloud_controller/paging/pagination_options'

module VCAP::CloudController
  class AppsV3Controller < RestController::BaseController
    def self.dependencies
      [:processes_handler, :process_presenter, :apps_handler, :app_presenter]
    end

    def inject_dependencies(dependencies)
      @process_handler = dependencies[:processes_handler]
      @app_handler = dependencies[:apps_handler]
      @app_presenter = dependencies[:app_presenter]
      @process_presenter = dependencies[:process_presenter]
    end

    get '/v3/apps', :list
    def list
      pagination_options = PaginationOptions.from_params(params)
      paginated_result   = @app_handler.list(pagination_options, @access_context)

      [HTTP::OK, @app_presenter.present_json_list(paginated_result)]
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
      message = AppUpdateMessage.create_from_http_request(guid, body)
      bad_request!(message.error) if message.error

      app = @app_handler.update(message, @access_context)
      app_not_found! if app.nil?

      [HTTP::OK, @app_presenter.present_json(app)]
    rescue AppsHandler::Unauthorized
      unauthorized!
    rescue AppsHandler::InvalidApp => e
      unprocessable!(e.message)
    end

    delete '/v3/apps/:guid', :delete
    def delete(guid)
      deleted = @app_handler.delete(guid, @access_context)
      app_not_found! unless deleted

      [HTTP::NO_CONTENT]
    rescue AppsHandler::DeleteWithProcesses
      unable_to_perform!('App deletion', 'Has child processes')
    rescue AppsHandler::Unauthorized
      app_not_found!
    end

    ###
    ### Processes
    ###

    get '/v3/apps/:guid/processes', :list_processes
    def list_processes(guid)
      app = @app_handler.show(guid, @access_context)
      app_not_found! if app.nil?

      pagination_options = PaginationOptions.from_params(params)
      paginated_result   = @process_handler.list(pagination_options, @access_context, app_guid: app.guid)

      [HTTP::OK, @process_presenter.present_json_list(paginated_result, "/v3/apps/#{guid}/processes")]
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
    rescue AppsHandler::IncorrectProcessSpace
      unable_to_perform!('Process addition', 'Process and App are not in the same space')
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

  def unable_to_perform!(msg, details)
    raise VCAP::Errors::ApiError.new_from_details('UnableToPerform', msg, details)
  end

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

  def unprocessable!(message)
    raise VCAP::Errors::ApiError.new_from_details('UnprocessableEntity', message)
  end
end
