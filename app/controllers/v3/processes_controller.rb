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
  end
end

