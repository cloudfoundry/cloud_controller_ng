require 'presenters/v3/process_presenter'
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

    get '/v3/apps/:guid/processes/:type', :show
    def show(app_guid, type)
      check_read_permissions!

      app = AppModel.where(guid: app_guid).eager(:space, space: :organization).all.first
      app_not_found! if app.nil? || !can_read?(app.space.guid, app.space.organization.guid)

      process = app.processes_dataset.where(type: type).first
      process_not_found! if process.nil?

      [HTTP::OK, @process_presenter.present_json(process)]
    end

    put '/v3/apps/:guid/processes/:type/scale', :scale
    def scale(app_guid, type)
      check_write_permissions!

      FeatureFlag.raise_unless_enabled!('app_scaling')

      request = parse_and_validate_json(body)
      message = ProcessScaleMessage.create_from_http_request(request)
      unprocessable!(message.errors.full_messages) if message.invalid?

      app = AppModel.where(guid: app_guid).eager(:space, space: :organization).all.first
      app_not_found! if app.nil? || !can_read?(app.space.guid, app.space.organization.guid)

      process = app.processes_dataset.where(type: type).first
      process_not_found! if process.nil?
      unauthorized! if !can_scale?(app.space.guid)

      ProcessScale.new(current_user, current_user_email).scale(process, message)

      [HTTP::OK, @process_presenter.present_json(process)]
    rescue ProcessScale::InvalidProcess => e
      unprocessable!(e.message)
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

    def can_scale?(space_guid)
      membership.has_any_roles?([Membership::SPACE_DEVELOPER], space_guid)
    end

    def app_not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'App not found')
    end

    def process_not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'Process not found')
    end
  end
end
