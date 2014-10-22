require 'presenters/v3/process_presenter'
require 'handlers/process_handler'

module VCAP::CloudController
  # TODO: would be nice not needing to use this BaseController
  class ProcessesController < RestController::BaseController
    get '/v3/processes/:guid', :show
    def show(guid)
      process_handler = ProcessHandler.new
      process = process_handler.find_by_guid(guid)
      if process.nil? || @access_context.cannot?(:read, process)
        raise VCAP::Errors::ApiError.new_from_details('NotFound')
      end
      process_presenter = ProcessPresenter.new(process).present
      [HTTP::OK, process_presenter.to_json]
    end

    post '/v3/processes', :create
    def create
      creation_opts = MultiJson.load(body).symbolize_keys

      process_handler = ProcessHandler.new
      desired_process = process_handler.new(creation_opts)

      if @access_context.cannot?(:create, desired_process)
        raise VCAP::Errors::ApiError.new_from_details('NotFound')
      end

      process = process_handler.persist!(desired_process)

      process_presenter = ProcessPresenter.new(process).present
      [HTTP::CREATED, process_presenter.to_json]
    rescue ProcessHandler::InvalidProcess => e
      raise VCAP::Errors::ApiError.new_from_details("UnprocessableEntity", e.message)
    end
  end
end

