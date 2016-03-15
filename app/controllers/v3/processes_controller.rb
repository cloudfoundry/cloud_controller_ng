require 'presenters/v3/process_presenter'
require 'cloud_controller/paging/pagination_options'
require 'actions/process_delete'
require 'queries/process_list_fetcher'
require 'queries/process_fetcher'
require 'messages/process_scale_message'
require 'actions/process_scale'
require 'actions/process_update'
require 'messages/process_update_message'
require 'messages/processes_list_message'
require 'controllers/v3/mixins/app_subresource'

class ProcessesController < ApplicationController
  include AppSubresource

  def index
    message = ProcessesListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    pagination_options = PaginationOptions.from_params(query_params)
    invalid_param!(pagination_options.errors.full_messages) unless pagination_options.valid?

    if app_nested?
      app, paginated_result = list_fetcher.fetch_for_app(app_guid: params[:app_guid], pagination_options: pagination_options)
      app_not_found! unless app && can_read?(app.space.guid, app.organization.guid)
    else
      paginated_result = if roles.admin?
                           list_fetcher.fetch_all(pagination_options: pagination_options)
                         else
                           list_fetcher.fetch_for_spaces(pagination_options: pagination_options, space_guids: readable_space_guids)
                         end
    end

    render status: :ok, json: process_presenter.present_json_list(paginated_result, base_url(resource: 'processes'))
  end

  def show
    if app_nested?
      process, app, space, org = ProcessFetcher.new.fetch_for_app_by_type(app_guid: params[:app_guid], process_type: params[:type])
      app_not_found! unless app && can_read?(space.guid, org.guid)
      process_not_found! unless process
    else
      process, space, org = ProcessFetcher.new.fetch(process_guid: params[:process_guid])
      process_not_found! unless process && can_read?(space.guid, org.guid)
    end

    render status: :ok, json: process_presenter.present_json(process)
  end

  def update
    guid    = params[:process_guid]
    message = ProcessUpdateMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    process = ProcessModel.where(guid: guid).eager(:space, :organization).all.first
    process_not_found! unless process && can_read?(process.space.guid, process.organization.guid)
    unauthorized! unless can_update?(process.space.guid)

    ProcessUpdate.new(current_user, current_user_email).update(process, message)

    render status: :ok, json: process_presenter.present_json(process)
  rescue ProcessUpdate::InvalidProcess => e
    unprocessable!(e.message)
  end

  def terminate
    if app_nested?
      process, app, space, org = ProcessFetcher.new.fetch_for_app_by_type(process_type: params[:type], app_guid: params[:app_guid])
      app_not_found! unless app && can_read?(space.guid, org.guid)
      process_not_found! unless process
    else
      process, space, org = ProcessFetcher.new.fetch(process_guid: params[:process_guid])
      process_not_found! unless process && can_read?(space.guid, org.guid)
    end

    unauthorized! unless can_terminate?(space.guid)

    index = params[:index].to_i
    instance_not_found! unless index < process.instances && index >= 0

    index_stopper.stop_index(process, index)

    head :no_content
  end

  def scale
    FeatureFlag.raise_unless_enabled!('app_scaling') unless roles.admin?

    message = ProcessScaleMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) if message.invalid?

    if app_nested?
      process, app, space, org = ProcessFetcher.new.fetch_for_app_by_type(process_type: params[:type], app_guid: params[:app_guid])
      app_not_found! unless app && can_read?(space.guid, org.guid)
      process_not_found! unless process
    else
      process, space, org = ProcessFetcher.new.fetch(process_guid: params[:process_guid])
      process_not_found! unless process && can_read?(space.guid, org.guid)
    end

    unauthorized! unless can_scale?(space.guid)

    ProcessScale.new(current_user, current_user_email).scale(process, message)

    render status: :accepted, json: process_presenter.present_json(process)
  rescue ProcessScale::InvalidProcess => e
    unprocessable!(e.message)
  end

  def stats
    if app_nested?
      process, app, space, org = ProcessFetcher.new.fetch_for_app_by_type(process_type: params[:type], app_guid: params[:app_guid])
      app_not_found! unless app && can_read?(space.guid, org.guid)
      process_not_found! unless process
      base_url = "/v3/apps/#{app.guid}/processes/#{process.type}/stats"
    else
      process, space, org = ProcessFetcher.new.fetch(process_guid: params[:process_guid])
      process_not_found! unless process && can_read?(space.guid, org.guid)
      base_url = "/v3/processes/#{process.guid}/stats"
    end

    process_stats = instances_reporters.stats_for_app(process)

    render status: :ok, json: process_presenter.present_json_stats(process, process_stats, base_url)
  end

  private

  def process_presenter
    ProcessPresenter.new
  end

  def index_stopper
    CloudController::DependencyLocator.instance.index_stopper
  end

  def can_update?(space_guid)
    roles.admin? || membership.has_any_roles?([Membership::SPACE_DEVELOPER], space_guid)
  end
  alias_method :can_terminate?, :can_update?
  alias_method :can_scale?, :can_update?

  def instance_not_found!
    resource_not_found!(:instance)
  end

  def process_not_found!
    resource_not_found!(:process)
  end

  def instances_reporters
    CloudController::DependencyLocator.instance.instances_reporters
  end

  def list_fetcher
    ProcessListFetcher.new
  end
end
