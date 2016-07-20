require 'presenters/v3/paginated_list_presenter'
require 'presenters/v3/process_presenter'
require 'presenters/v3/process_stats_presenter'
require 'cloud_controller/paging/pagination_options'
require 'actions/process_delete'
require 'queries/process_list_fetcher'
require 'queries/process_fetcher'
require 'messages/process_scale_message'
require 'actions/process_scale'
require 'actions/process_terminate'
require 'actions/process_update'
require 'messages/process_update_message'
require 'messages/processes_list_message'
require 'controllers/v3/mixins/sub_resource'

class ProcessesController < ApplicationController
  include SubResource

  def index
    message = ProcessesListMessage.from_params(subresource_query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    if app_nested?
      app, dataset = ProcessListFetcher.new(message).fetch_for_app
      app_not_found! unless app && can_read?(app.space.guid, app.organization.guid)
    else
      dataset = if roles.admin? || roles.admin_read_only?
                  ProcessListFetcher.new(message).fetch_all
                else
                  ProcessListFetcher.new(message).fetch_for_spaces(space_guids: readable_space_guids)
                end
    end

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(dataset, base_url(resource: 'processes'), message)
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

    render status: :ok, json: Presenters::V3::ProcessPresenter.new(process, show_secrets: can_see_secrets?(space))
  end

  def update
    guid    = params[:process_guid]
    message = ProcessUpdateMessage.create_from_http_request(unmunged_body)
    unprocessable!(message.errors.full_messages) unless message.valid?

    process = ProcessModel.where(guid: guid).eager(:space, :organization).all.first
    process_not_found! unless process && can_read?(process.space.guid, process.organization.guid)
    unauthorized! unless can_write?(process.space.guid)

    ProcessUpdate.new(current_user.guid, current_user_email).update(process, message)

    render status: :ok, json: Presenters::V3::ProcessPresenter.new(process)
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

    unauthorized! unless can_write?(space.guid)

    ProcessTerminate.new(current_user.guid, current_user_email, process, params[:index].to_i).terminate

    head :no_content
  rescue ProcessTerminate::InstanceNotFound
    resource_not_found!(:instance)
  end

  def scale
    FeatureFlag.raise_unless_enabled!(:app_scaling)

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

    unauthorized! unless can_write?(space.guid)

    ProcessScale.new(current_user, current_user_email, process, message).scale

    render status: :accepted, json: Presenters::V3::ProcessPresenter.new(process)
  rescue ProcessScale::InvalidProcess => e
    unprocessable!(e.message)
  end

  def stats
    if app_nested?
      process, app, space, org = ProcessFetcher.new.fetch_for_app_by_type(process_type: params[:type], app_guid: params[:app_guid])
      app_not_found! unless app && can_read?(space.guid, org.guid)
      process_not_found! unless process
    else
      process, space, org = ProcessFetcher.new.fetch(process_guid: params[:process_guid])
      process_not_found! unless process && can_read?(space.guid, org.guid)
    end

    process_stats = instances_reporters.stats_for_app(process)

    render status: :ok, json: Presenters::V3::ProcessStatsPresenter.new(process.type, process_stats)
  end

  private

  def process_not_found!
    resource_not_found!(:process)
  end

  def instances_reporters
    CloudController::DependencyLocator.instance.instances_reporters
  end
end
