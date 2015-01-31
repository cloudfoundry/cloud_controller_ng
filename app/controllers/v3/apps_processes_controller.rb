require 'presenters/v3/process_presenter'
require 'handlers/processes_handler'
require 'handlers/procfile_handler'
require 'handlers/apps_handler'
require 'cloud_controller/paging/pagination_options'
require 'cloud_controller/procfile'

module VCAP::CloudController
  class AppsProcessesController < RestController::BaseController
    def self.dependencies
      [:processes_handler, :process_presenter, :apps_handler, :procfile_handler]
    end

    def inject_dependencies(dependencies)
      @app_handler       = dependencies[:apps_handler]
      @processes_handler = dependencies[:processes_handler]
      @process_presenter = dependencies[:process_presenter]
      @procfile_handler  = dependencies[:procfile_handler]
    end

    get '/v3/apps/:guid/processes', :list_processes
    def list_processes(guid)
      app = @app_handler.show(guid, @access_context)
      app_not_found! if app.nil?

      pagination_options = PaginationOptions.from_params(params)
      paginated_result   = @processes_handler.list(pagination_options, @access_context, app_guid: app.guid)

      [HTTP::OK, @process_presenter.present_json_list(paginated_result, "/v3/apps/#{guid}/processes")]
    end

    put '/v3/apps/:guid/processes', :add_process
    def add_process(guid)
      opts = MultiJson.load(body)

      app = @app_handler.show(guid, @access_context)
      app_not_found! if app.nil?

      process = @processes_handler.show(opts['process_guid'], @access_context)
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

      process = @processes_handler.show(opts['process_guid'], @access_context)
      process_not_found! if process.nil?

      @app_handler.remove_process(app, process, @access_context)

      [HTTP::NO_CONTENT]
    rescue MultiJson::ParseError => e
      raise VCAP::Errors::ApiError.new_from_details('MessageParseError', e.message)
    rescue AppsHandler::Unauthorized
      app_not_found!
    end

    put '/v3/apps/:guid/procfile', :process_procfile
    def process_procfile(guid)
      app = @app_handler.show(guid, @access_context)
      app_not_found! if app.nil?

      procfile = Procfile.load(body)
      @procfile_handler.process_procfile(app, procfile, @access_context)

      pagination_options = PaginationOptions.from_params(params)
      paginated_result   = @processes_handler.list(pagination_options, @access_context, app_guid: app.guid)

      [HTTP::OK, @process_presenter.present_json_list(paginated_result, "/v3/apps/#{guid}/processes")]
    rescue Procfile::ParseError => e
      raise VCAP::Errors::ApiError.new_from_details('MessageParseError', e.message)
    rescue ProcfileHandler::Unauthorized
      app_not_found!
    rescue ProcessesHandler::Unauthorized
      app_not_found!
    rescue AppsHandler::Unauthorized
      app_not_found!
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
  end
end
