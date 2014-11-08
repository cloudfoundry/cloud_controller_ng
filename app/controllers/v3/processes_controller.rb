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
      process = @process_handler.show(guid, @access_context)
      not_found! if process.nil?

      process_presenter = ProcessPresenter.new(process)
      [HTTP::OK, process_presenter.present_json]
    end

    post '/v3/processes', :create
    def create
      create_message = ProcessCreateMessage.create_from_http_request(body)
      bad_request!(create_message.error) unless create_message.valid?

      process = @process_handler.create(create_message, @access_context)

      process_presenter = ProcessPresenter.new(process)
      [HTTP::CREATED, process_presenter.present_json]

    rescue ProcessesHandler::InvalidProcess => e
      unprocessable!(e.message)
    rescue ProcessesHandler::Unauthorized
      unauthorized!
    end

    patch '/v3/processes/:guid', :update
    def update(guid)
      update_message = ProcessUpdateMessage.create_from_http_request(guid, body)
      bad_request!(update_message.error) unless update_message.valid?

      process = @process_handler.update(update_message, @access_context)

      not_found! if process.nil?

      process_presenter = ProcessPresenter.new(process)
      [HTTP::OK, process_presenter.present_json]
    rescue ProcessesHandler::InvalidProcess => e
      unprocessable!(e.message)
    rescue ProcessesHandler::Unauthorized
      unauthorized!
    end

    delete '/v3/processes/:guid', :delete
    def delete(guid)
      deleted = @process_handler.delete(guid)
      not_found! unless deleted
      [HTTP::NO_CONTENT]
    end

    private

    def not_found!
      raise VCAP::Errors::ApiError.new_from_details('NotFound')
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
