require 'presenters/v3/process_presenter'
require 'handlers/processes_handler'
require 'cloud_controller/paging/pagination_options'
require 'queries/process_delete_fetcher'
require 'actions/process_delete'

module VCAP::CloudController
  # TODO: would be nice not needing to use this BaseController
  class ProcessesController < RestController::BaseController
    def self.dependencies
      [:process_repository, :processes_handler, :process_presenter]
    end
    def inject_dependencies(dependencies)
      @processes_handler = dependencies[:processes_handler]
      @process_presenter = dependencies[:process_presenter]
    end

    get '/v3/processes', :list
    def list
      pagination_options = PaginationOptions.from_params(params)
      paginated_result   = @processes_handler.list(pagination_options, @access_context)

      [HTTP::OK, @process_presenter.present_json_list(paginated_result, '/v3/processes')]
    end

    get '/v3/processes/:guid', :show
    def show(guid)
      process = @processes_handler.show(guid, @access_context)
      not_found! if process.nil?

      [HTTP::OK, @process_presenter.present_json(process)]
    end

    post '/v3/processes', :create
    def create
      create_message = ProcessCreateMessage.create_from_http_request(body)
      bad_request!(create_message.error) unless create_message.valid?

      process = @processes_handler.create(create_message, @access_context)

      [HTTP::CREATED, @process_presenter.present_json(process)]

    rescue ProcessesHandler::InvalidProcess => e
      unprocessable!(e.message)
    rescue ProcessesHandler::Unauthorized
      unauthorized!
    end

    patch '/v3/processes/:guid', :update
    def update(guid)
      update_message = ProcessUpdateMessage.create_from_http_request(guid, body)
      bad_request!('Invalid JSON') if update_message.nil?

      errors = update_message.validate
      unprocessable!(errors.first) if errors.length > 0

      process = @processes_handler.update(update_message, @access_context)
      not_found! if process.nil?

      [HTTP::OK, @process_presenter.present_json(process)]
    rescue ProcessesHandler::InvalidProcess => e
      unprocessable!(e.message)
    rescue ProcessesHandler::Unauthorized
      unauthorized!
    end

    delete '/v3/processes/:guid', :delete
    def delete(guid)
      check_write_permissions!

      process, space, org = process_delete_fetcher.fetch(guid)
      not_found! if process.nil? || !can_read?(space.guid, org.guid)
      unauthorized! unless can_delete?(space.guid)

      ProcessDelete.new(space, current_user, current_user_email).delete(process)

      [HTTP::NO_CONTENT]
    end

    private

    def process_delete_fetcher
      @process_delete_fetcher ||= ProcessDeleteFetcher.new
    end

    def membership
      @membership ||= Membership.new(current_user)
    end

    def can_read?(space_guid, org_guid)
      membership.has_any_roles?([Membership::SPACE_DEVELOPER,
                                 Membership::SPACE_MANAGER,
                                 Membership::SPACE_AUDITOR,
                                 Membership::ORG_MANAGER], space_guid, org_guid)
    end

    def can_delete?(space_guid)
      membership.has_any_roles?([Membership::SPACE_DEVELOPER], space_guid)
    end

    def not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'Process not found')
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
