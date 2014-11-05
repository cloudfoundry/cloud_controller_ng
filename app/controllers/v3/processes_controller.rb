require 'presenters/v3/process_presenter'
require 'repositories/process_repository'
require 'handlers/processes_handler'

module VCAP::CloudController
  # TODO: would be nice not needing to use this BaseController
  class ProcessesController < RestController::BaseController
    def inject_dependencies(dependencies)
      @process_repository = dependencies[:process_repository]
      @process_handler = ProcessesHandler.new(@process_repository, @access_context)
    end

    get '/v3/processes/:guid', :show
    def show(guid)
      process = @process_handler.show(guid)
      process_presenter = ProcessPresenter.new(process)
      [HTTP::OK, process_presenter.present_json]
    end


    post '/v3/processes', :create
    def create
      process = @process_handler.create(body)
      process_presenter = ProcessPresenter.new(process)
      [HTTP::CREATED, process_presenter.present_json]
    end

    patch '/v3/processes/:guid', :update
    def update(guid)
      process = @process_handler.update(guid, body)
      process_presenter = ProcessPresenter.new(process)
      [HTTP::OK, process_presenter.present_json]
    end

    delete '/v3/processes/:guid', :delete
    def delete(guid)
      @process_handler.delete(guid)
      [HTTP::NO_CONTENT]
    end
  end
end
