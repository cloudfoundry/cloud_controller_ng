require 'presenters/v3/process_presenter'
require 'repositories/process_repository'

module VCAP::CloudController
  # TODO: would be nice not needing to use this BaseController
  class ProcessesController < RestController::BaseController
    def inject_dependencies(dependencies)
      @process_repository = dependencies[:process_repository]
    end

    get '/v3/processes/:guid', :show
    def show(guid)
      process = @process_repository.find_by_guid(guid)
      if process.nil? || @access_context.cannot?(:read, process)
        raise VCAP::Errors::ApiError.new_from_details('NotFound')
      end

      process_presenter = ProcessPresenter.new(process)
      [HTTP::OK, process_presenter.present_json]
    end

    post '/v3/processes', :create
    post '/v3/apps/:app_guid/processes', :create
    def create(app_guid=nil)
      creation_opts = MultiJson.load(body).symbolize_keys
      creation_opts[:app_guid] = app_guid

      desired_process = @process_repository.new_process(creation_opts)

      if @access_context.cannot?(:create, desired_process)
        raise VCAP::Errors::ApiError.new_from_details('NotAuthorized')
      end

      process = @process_repository.persist!(desired_process)

      process_presenter = ProcessPresenter.new(process)
      [HTTP::CREATED, process_presenter.present_json]

    rescue ProcessRepository::InvalidProcess => e
      raise VCAP::Errors::ApiError.new_from_details('UnprocessableEntity', e.message)
    rescue MultiJson::ParseError => e
      raise VCAP::Errors::ApiError.new_from_details('MessageParseError', e.message)
    end

    patch '/v3/processes/:guid', :update
    def update(guid)
      changes = MultiJson.load(body).symbolize_keys

      @process_repository.find_by_guid_for_update(guid) do |initial_process|
        if initial_process.nil? || @access_context.cannot?(:update, initial_process)
          raise VCAP::Errors::ApiError.new_from_details('NotFound')
        end

        desired_process = @process_repository.update(initial_process, changes)

        if @access_context.cannot?(:update, desired_process)
          raise VCAP::Errors::ApiError.new_from_details('NotFound')
        end

        process = @process_repository.persist!(desired_process)

        process_presenter = ProcessPresenter.new(process)
        [HTTP::OK, process_presenter.present_json]
      end
    rescue MultiJson::ParseError => e
      raise VCAP::Errors::ApiError.new_from_details('MessageParseError', e.message)
    end

    delete '/v3/processes/:guid', :delete
    def delete(guid)
      @process_repository.find_by_guid_for_update(guid) do |process|
        if process.nil? || @access_context.cannot?(:delete, process)
          raise VCAP::Errors::ApiError.new_from_details('NotFound')
        end

        @process_repository.delete(process)
        [HTTP::NO_CONTENT]
      end
    end
  end
end
