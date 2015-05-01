require 'presenters/v3/process_presenter'
require 'cloud_controller/paging/pagination_options'
require 'actions/process_delete'
require 'queries/process_scale_fetcher'
require 'messages/process_scale_message'
require 'actions/process_scale'
require 'actions/process_update'
require 'messages/process_update_message'

module VCAP::CloudController
  class ProcessesController < RestController::BaseController
    def self.dependencies
      [:process_presenter]
    end
    def inject_dependencies(dependencies)
      @process_presenter = dependencies[:process_presenter]
    end

    get '/v3/processes', :list
    def list
      check_read_permissions!

      pagination_options = PaginationOptions.from_params(params)
      invalid_param!(pagination_options.errors.full_messages) unless pagination_options.valid?
      invalid_param!("Unknown query param(s) '#{params.keys.join("', '")}'") if params.any?

      if membership.admin?
        paginated_result = ProcessListFetcher.new.fetch_all(pagination_options)
      else
        space_guids = membership.space_guids_for_roles([Membership::SPACE_DEVELOPER, Membership::SPACE_MANAGER, Membership::SPACE_AUDITOR, Membership::ORG_MANAGER])
        paginated_result = ProcessListFetcher.new.fetch(pagination_options, space_guids)
      end

      [HTTP::OK, @process_presenter.present_json_list(paginated_result, '/v3/processes')]
    end

    get '/v3/processes/:guid', :show
    def show(guid)
      check_read_permissions!

      process = App.where(guid: guid).eager(:space, :organization).all.first

      not_found! if process.nil? || !can_read?(process.space.guid, process.organization.guid)

      [HTTP::OK, @process_presenter.present_json(process)]
    end

    patch '/v3/processes/:guid', :update
    def update(guid)
      check_write_permissions!

      request = parse_and_validate_json(body)
      message = ProcessUpdateMessage.create_from_http_request(guid, request)
      unprocessable!(message.errors.full_messages) unless message.valid?

      process = App.where(guid: guid).eager(:space, :organization).all.first
      not_found! if process.nil? || !can_read?(process.space.guid, process.organization.guid)
      unauthorized! if !can_update?(process.space.guid)

      ProcessUpdate.new(current_user, current_user_email).update(process, message)

      [HTTP::OK, @process_presenter.present_json(process)]
    rescue ProcessUpdate::InvalidProcess => e
      unprocessable!(e.message)
    end

    put '/v3/processes/:guid/scale', :scale
    def scale(guid)
      check_write_permissions!

      FeatureFlag.raise_unless_enabled!('app_scaling')

      request = parse_and_validate_json(body)
      message = ProcessScaleMessage.create_from_http_request(request)
      unprocessable!(message.errors.full_messages) if message.invalid?

      process, space, org = ProcessScaleFetcher.new.fetch(guid)
      not_found! if process.nil? || !can_read?(space.guid, org.guid)
      unauthorized! if !can_scale?(space.guid)

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

    def can_update?(space_guid)
      membership.has_any_roles?([Membership::SPACE_DEVELOPER], space_guid)
    end

    def can_scale?(space_guid)
      can_update?(space_guid)
    end

    def not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'Process not found')
    end
  end
end
