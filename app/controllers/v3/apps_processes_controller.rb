class AppsProcessesController < ApplicationController
  def index
    message = ProcessesListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    pagination_options = PaginationOptions.from_params(query_params)
    invalid_param!(pagination_options.errors.full_messages) unless pagination_options.valid?

    app = AppModel.where(guid: params[:guid]).eager(:space, space: :organization).all.first
    app_not_found! unless app && can_read?(app.space.guid, app.space.organization.guid)

    paginated_result = SequelPaginator.new.get_page(app.processes_dataset, pagination_options)

    render :ok, json: process_presenter.present_json_list(paginated_result, "/v3/apps/#{params[:guid]}/processes")
  end

  def show
    app = AppModel.where(guid: params[:guid]).eager(:space, space: :organization).all.first
    app_not_found! unless app && can_read?(app.space.guid, app.space.organization.guid)

    process = app.processes_dataset.where(type: params[:type]).first
    process_not_found! if process.nil?

    render :ok, json: process_presenter.present_json(process)
  end

  def scale
    FeatureFlag.raise_unless_enabled!('app_scaling') unless roles.admin?

    message = ProcessScaleMessage.create_from_http_request(params['body'])
    unprocessable!(message.errors.full_messages) if message.invalid?

    app = AppModel.where(guid: params[:guid]).eager(:space, space: :organization).all.first
    app_not_found! unless app && can_read?(app.space.guid, app.space.organization.guid)

    process = app.processes_dataset.where(type: params[:type]).first
    process_not_found! if process.nil?
    unauthorized! unless can_scale?(app.space.guid)

    begin
      ProcessScale.new(current_user, current_user_email).scale(process, message)
    rescue ProcessScale::InvalidProcess => e
      unprocessable!(e.message)
    end

    render :ok, json: process_presenter.present_json(process)
  end

  def stats
    app = AppModel.where(guid: params[:guid]).first
    app_not_found! unless app && can_stats?(app.space.guid)

    process = app.processes_dataset.where(type: params[:type]).first
    process_not_found! if process.nil?

    process_stats = instances_reporters.stats_for_app(process)

    render status: :ok, json: process_presenter.present_json_stats(process, process_stats, "/v3/apps/#{params[:guid]}/processes/#{params[:type]}/stats")
  end

  def terminate
    index_stopper = IndexStopper.new(runners)
    process_index = params[:index].to_i
    process_type = params[:type]

    app = AppModel.where(guid: params[:guid]).eager(:space, space: :organization).all.first
    app_not_found! unless app && can_read?(app.space.guid, app.space.organization.guid)

    process = app.processes_dataset.where(type: process_type).first
    process_not_found! if process.nil?
    unauthorized! unless can_terminate?(app.space.guid)

    instance_not_found! unless process_index < process.instances && process_index >= 0

    index_stopper.stop_index(process, process_index)

    head :no_content
  end

  private

  def process_presenter
    ProcessPresenter.new
  end

  def can_read?(space_guid, org_guid)
    roles.admin? ||
    membership.has_any_roles?([Membership::SPACE_DEVELOPER,
                               Membership::SPACE_MANAGER,
                               Membership::SPACE_AUDITOR,
                               Membership::ORG_MANAGER], space_guid, org_guid)
  end

  def can_scale?(space_guid)
    roles.admin? ||
    membership.has_any_roles?([Membership::SPACE_DEVELOPER], space_guid)
  end
  alias_method :can_terminate?, :can_scale?
  alias_method :can_stats?, :can_scale?

  def app_not_found!
    resource_not_found!(:app)
  end

  def process_not_found!
    resource_not_found!(:process)
  end

  def instance_not_found!
    resource_not_found!(:instance)
  end

  def runners
    CloudController::DependencyLocator.instance.runners
  end

  def instances_reporters
    CloudController::DependencyLocator.instance.instances_reporters
  end
end
