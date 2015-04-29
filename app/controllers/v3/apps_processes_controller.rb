require 'presenters/v3/process_presenter'
require 'handlers/apps_handler'
require 'cloud_controller/paging/pagination_options'

module VCAP::CloudController
  class AppsProcessesController < RestController::BaseController
    def self.dependencies
      [:process_presenter]
    end

    def inject_dependencies(dependencies)
      @process_presenter = dependencies[:process_presenter]
    end

    get '/v3/apps/:guid/processes', :list_processes
    def list_processes(guid)
      check_read_permissions!

      pagination_options = PaginationOptions.from_params(params)
      invalid_param!(pagination_options.errors.full_messages) unless pagination_options.valid?
      invalid_param!("Unknown query param(s) '#{params.keys.join("', '")}'") if params.any?

      app = AppModel.where(guid: guid).eager(:space, space: :organization).all.first
      app_not_found! if app.nil? || !can_read?(app.space.guid, app.space.organization.guid)

      paginated_result = SequelPaginator.new.get_page(app.processes_dataset, pagination_options)

      [HTTP::OK, @process_presenter.present_json_list(paginated_result, "/v3/apps/#{guid}/processes")]
    end

    private

    def membership
      @membership ||= Membership.new(current_user)
    end

    def can_read?(space_guid, org_guid)
      membership.has_any_roles?([Membership::SPACE_DEVELOPER,
                                 Membership::SPACE_MANAGER,
                                 Membership::SPACE_AUDITOR,
                                 Membership::ORG_MANAGER], space_guid, org_guid)
    end

    def app_not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'App not found')
    end
  end
end
