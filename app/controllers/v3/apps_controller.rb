require 'presenters/v3/app_presenter'
require 'queries/app_list_fetcher'
require 'messages/apps_list_message'
require 'queries/app_fetcher'
require 'messages/app_create_message'
require 'actions/app_create'
require 'cloud_controller/paging/pagination_options'
require 'messages/buildpack_request_validator'
require 'messages/app_update_message'
require 'actions/app_update'
require 'queries/app_delete_fetcher'
require 'actions/app_delete'
require 'actions/app_start'
require 'actions/app_stop'
require 'queries/assign_current_droplet_fetcher'
require 'actions/set_current_droplet'
require 'builders/app_create_request_builder'

class AppsV3Controller < ApplicationController
  def index
    message = AppsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    pagination_options = PaginationOptions.from_params(query_params)
    invalid_param!(pagination_options.errors.full_messages) unless pagination_options.valid?

    paginated_result = roles.admin? ? AppListFetcher.new.fetch_all(pagination_options, message) :
      VCAP::CloudController::AppListFetcher.new.fetch(pagination_options, message, allowed_space_guids)

    render status: :ok, json: AppPresenter.new.present_json_list(paginated_result, message)
  end

  def show
    app, space, org = AppFetcher.new.fetch(params[:guid])

    app_not_found! if app.nil? || !can_read?(space.guid, org.guid)

    render status: :ok, json: AppPresenter.new.present_json(app)
  end

  def create
    assembled_request = AppCreateRequestBuilder.new.build(params[:body])
    message = AppCreateMessage.create_from_http_request(assembled_request)
    unprocessable!(message.errors.full_messages) unless message.valid?

    buildpack_validator = BuildpackRequestValidator.new({ buildpack: message.buildpack })
    unprocessable!(buildpack_validator.errors.full_messages) unless buildpack_validator.valid?

    space_not_found! unless can_create?(message.space_guid)

    app = AppCreate.new(current_user, current_user_email).create(message)

    render status: :created, json: AppPresenter.new.present_json(app)
  rescue AppCreate::InvalidApp => e
    unprocessable!(e.message)
  end

  def update
    message = AppUpdateMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    app, space, org = AppFetcher.new.fetch(params[:guid])

    app_not_found! if app.nil? || !can_read?(space.guid, org.guid)
    unauthorized! unless can_update?(space.guid)

    buildpack_validator = BuildpackRequestValidator.new({ buildpack: message.buildpack })
    unprocessable!(buildpack_validator.errors.full_messages) unless buildpack_validator.valid?

    app = AppUpdate.new(current_user, current_user_email).update(app, message)

    render status: :ok, json: AppPresenter.new.present_json(app)
  rescue AppUpdate::DropletNotFound
    droplet_not_found!
  rescue AppUpdate::InvalidApp => e
    unprocessable!(e.message)
  end

  def destroy
    app, space, org  = AppDeleteFetcher.new.fetch(params[:guid])

    app_not_found! if app.nil? || !can_read?(space.guid, org.guid)
    unauthorized! unless can_delete?(space.guid)

    AppDelete.new(current_user.guid, current_user_email).delete(app)

    head :no_content
  end

  def start
    app, space, org = AppFetcher.new.fetch(params[:guid])
    app_not_found! if app.nil? || !can_read?(space.guid, org.guid)
    unauthorized! unless can_start?(space.guid)

    AppStart.new(current_user, current_user_email).start(app)

    render status: :ok, json: AppPresenter.new.present_json(app)
  rescue AppStart::DropletNotFound
    droplet_not_found!
  rescue AppStart::InvalidApp => e
    unprocessable!(e.message)
  end

  def stop
    app, space, org = AppFetcher.new.fetch(params[:guid])
    app_not_found! if app.nil? || !can_read?(space.guid, org.guid)
    unauthorized! unless can_stop?(space.guid)

    AppStop.new(current_user, current_user_email).stop(app)

    render status: :ok, json: AppPresenter.new.present_json(app)
  rescue AppStop::InvalidApp => e
    unprocessable!(e.message)
  end

  def show_environment
    app, space, org = AppFetcher.new.fetch(params[:guid])
    app_not_found! if app.nil? || !can_read?(space.guid, org.guid)
    unauthorized! unless can_read_envs?(space.guid)

    render status: :ok, json: AppPresenter.new.present_json_env(app)
  end

  def assign_current_droplet
    app_guid = params[:guid]
    droplet_guid = params[:body]['droplet_guid']
    app, space, org, droplet = AssignCurrentDropletFetcher.new.fetch(app_guid, droplet_guid)

    app_not_found! if app.nil? || !can_read?(space.guid, org.guid)
    unauthorized! unless can_update?(space.guid)
    unprocessable!('Stop the app before changing droplet') if app.desired_state != 'STOPPED'

    droplet_not_found! if droplet.nil?

    app = SetCurrentDroplet.new(current_user, current_user_email).update_to(app, droplet)

    render status: :ok, json: AppPresenter.new.present_json(app)
  rescue SetCurrentDroplet::InvalidApp => e
    unprocessable!(e.message)
  end

  private

  def membership
    @membership ||= Membership.new(current_user)
  end

  def can_read?(space_guid, org_guid)
    roles.admin? ||
      membership.has_any_roles?([VCAP::CloudController::Membership::SPACE_DEVELOPER,
                                 VCAP::CloudController::Membership::SPACE_MANAGER,
                                 VCAP::CloudController::Membership::SPACE_AUDITOR,
                                 VCAP::CloudController::Membership::ORG_MANAGER], space_guid, org_guid)
  end

  def allowed_space_guids
    membership.space_guids_for_roles([VCAP::CloudController::Membership::SPACE_DEVELOPER,
                                      VCAP::CloudController::Membership::SPACE_MANAGER,
                                      VCAP::CloudController::Membership::SPACE_AUDITOR,
                                      VCAP::CloudController::Membership::ORG_MANAGER])
  end

  def can_create?(space_guid)
    roles.admin? ||
      membership.has_any_roles?([Membership::SPACE_DEVELOPER], space_guid)
  end
  alias_method :can_update?, :can_create?
  alias_method :can_delete?, :can_create?
  alias_method :can_start?, :can_create?
  alias_method :can_stop?, :can_create?
  alias_method :can_read_envs?, :can_create?

  def droplet_not_found!
    raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'Droplet not found')
  end

  def space_not_found!
    raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'Space not found')
  end

  def app_not_found!
    raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'App not found')
  end
end
