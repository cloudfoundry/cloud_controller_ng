require 'presenters/v3/paginated_list_presenter'
require 'presenters/v3/process_presenter'
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
require 'controllers/v3/mixins/app_subresource'

class ProcessesController < ApplicationController
  include AppSubresource

  def index
    message = ProcessesListMessage.from_params(app_subresource_query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    list_fetcher = ProcessListFetcher.new(message)

    if app_nested?
      app, paginated_result = list_fetcher.fetch_for_app
      app_not_found! unless app && can_read?(app.space.guid, app.organization.guid)
    else
      paginated_result = if roles.admin?
                           list_fetcher.fetch_all
                         else
                           list_fetcher.fetch_for_spaces(space_guids: readable_space_guids)
                         end
    end

    render status: :ok, json: PaginatedListPresenter.new(paginated_result, base_url(resource: 'processes'), message).to_json
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

    render status: :ok, json: ProcessPresenter.new(process, base_process_url).to_json
  end

  def update
    guid    = params[:process_guid]
    message = ProcessUpdateMessage.create_from_http_request(unmunged_body)
    unprocessable!(message.errors.full_messages) unless message.valid?

    process = ProcessModel.where(guid: guid).eager(:space, :organization).all.first
    process_not_found! unless process && can_read?(process.space.guid, process.organization.guid)
    unauthorized! unless can_write?(process.space.guid)

    ProcessUpdate.new(current_user.guid, current_user_email).update(process, message)

    render status: :ok, json: ProcessPresenter.new(process, base_process_url).to_json
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

    unauthorized! unless can_write?(space.guid)

    ProcessScale.new(current_user, current_user_email, process, message).scale

    render status: :accepted, json: ProcessPresenter.new(process, base_process_url).to_json
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

    render status: :ok, json: ProcessStatsPresenter.new(process.type, process_stats).to_json
  end

  private

  def base_process_url
    app_nested? ? "/v3/apps/#{params[:app_guid]}/processes/#{params[:type]}" : "/v3/processes/#{params[:process_guid]}"
  end

  def process_not_found!
    resource_not_found!(:process)
  end

  def instances_reporters
    CloudController::DependencyLocator.instance.instances_reporters
  end
end
