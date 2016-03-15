require 'presenters/v3/process_presenter'
require 'cloud_controller/paging/pagination_options'
require 'actions/process_delete'
require 'queries/process_scale_fetcher'
require 'queries/process_list_fetcher'
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

    if roles.admin?
      paginated_result = ProcessListFetcher.new.fetch_all(pagination_options)
    else
      space_guids = membership.space_guids_for_roles([Membership::SPACE_DEVELOPER, Membership::SPACE_MANAGER, Membership::SPACE_AUDITOR, Membership::ORG_MANAGER])
      paginated_result = ProcessListFetcher.new.fetch(pagination_options, space_guids)
    end

    render status: :ok, json: process_presenter.present_json_list(paginated_result, '/v3/processes')
  end

  def show
    guid = params[:guid]
    process = ProcessModel.where(guid: guid).eager(:space, :organization).all.first
    process_not_found! unless process && can_read?(process.space.guid, process.organization.guid)
    render status: :ok, json: process_presenter.present_json(process)
  end

  def update
    guid = params[:guid]
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
    process_guid = params[:guid]
    process = ProcessModel.where(guid: process_guid).eager(:space, :organization).all.first
    process_not_found! unless process && can_read?(process.space.guid, process.organization.guid)
    unauthorized! unless can_terminate?(process.space.guid)

    index = params[:index].to_i
    instance_not_found! unless index < process.instances && index >= 0

    index_stopper.stop_index(process, index)

    head :no_content
  end

  def scale
    FeatureFlag.raise_unless_enabled!('app_scaling') unless roles.admin?

    message = ProcessScaleMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) if message.invalid?

    process, space, org = ProcessScaleFetcher.new.fetch(params[:guid])
    process_not_found! unless process && can_read?(space.guid, org.guid)
    unauthorized! unless can_scale?(space.guid)

    ProcessScale.new(current_user, current_user_email).scale(process, message)

    render status: :accepted, json: process_presenter.present_json(process)
  rescue ProcessScale::InvalidProcess => e
    unprocessable!(e.message)
  end

  def stats
    guid = params[:guid]
    process = ProcessModel.where(guid: guid).eager(:space).all.first
    process_stats = instances_reporters.stats_for_app(process)

    process_not_found! unless process && can_stats?(process.space.guid)

    render status: :ok, json: process_presenter.present_json_stats(process, process_stats, "/v3/processes/#{guid}/stats")
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
  alias_method :can_stats?, :can_update?

  def instance_not_found!
    resource_not_found!(:instance)
  end

  def process_not_found!
    resource_not_found!(:process)
  end

  def instances_reporters
    CloudController::DependencyLocator.instance.instances_reporters
  end
end
