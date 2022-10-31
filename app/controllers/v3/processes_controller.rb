require 'presenters/v3/paginated_list_presenter'
require 'presenters/v3/process_presenter'
require 'presenters/v3/process_stats_presenter'
require 'cloud_controller/paging/pagination_options'
require 'actions/process_delete'
require 'fetchers/process_list_fetcher'
require 'fetchers/process_fetcher'
require 'actions/process_scale'
require 'actions/process_terminate'
require 'actions/process_update'
require 'messages/process_scale_message'
require 'messages/process_update_message'
require 'messages/processes_list_message'
require 'controllers/v3/mixins/app_sub_resource'
require 'cloud_controller/strategies/non_manifest_strategy'

class ProcessesController < ApplicationController
  include AppSubResource

  before_action :find_process_and_space, except: :index
  before_action :ensure_can_write, only: %i(update terminate scale)

  def index
    message = ProcessesListMessage.from_params(subresource_query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    if app_nested?
      app, dataset = ProcessListFetcher.fetch_for_app(message, eager_loaded_associations: Presenters::V3::ProcessPresenter.associated_resources)

      app_not_found! unless app && permission_queryer.can_read_from_space?(app.space.id, app.space.organization_id)
    else
      dataset = if permission_queryer.can_read_globally?
                  ProcessListFetcher.fetch_all(message, eager_loaded_associations: Presenters::V3::ProcessPresenter.associated_resources)
                else
                  ProcessListFetcher.fetch_for_spaces(
                    message,
                    space_guids: permission_queryer.readable_space_guids,
                    eager_loaded_associations: Presenters::V3::ProcessPresenter.associated_resources
                  )
                end
    end

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::ProcessPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: base_url(resource: 'processes'),
      message: message
    )
  end

  def show
    # TODO
    render status: :ok, json: Presenters::V3::ProcessPresenter.new(@process, show_secrets: permission_queryer.can_read_secrets_in_space?(@space.id, @space.organization_id))
  end

  def update
    message = ProcessUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    ProcessUpdate.new(user_audit_info).update(@process, message, NonManifestStrategy)

    render status: :ok, json: Presenters::V3::ProcessPresenter.new(@process)
  rescue ProcessUpdate::InvalidProcess => e
    unprocessable!(e.message)
  end

  def terminate
    ProcessTerminate.new(user_audit_info, @process, hashed_params[:index].to_i).terminate

    head :no_content
  rescue ProcessTerminate::InstanceNotFound
    resource_not_found!(:instance)
  end

  def scale
    FeatureFlag.raise_unless_enabled!(:app_scaling)

    message = ProcessScaleMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) if message.invalid?

    @process.skip_process_version_update = true if message.requested?(:memory_in_mb)
    ProcessScale.new(user_audit_info, @process, message).scale
    TelemetryLogger.v3_emit(
      'scale-app',
      {
        'app-id' => @process.app_guid,
        'user-id' => current_user.guid
      },
      {
        'instance-count' => message.instances,
        'memory-in-mb' => message.memory_in_mb,
        'disk-in-mb' => message.disk_in_mb,
        'log-rate-in-bytes-per-second' => message.log_rate_limit_in_bytes_per_second,
        'process-type' => @process.type
      }
    )
    render status: :accepted, json: Presenters::V3::ProcessPresenter.new(@process)
  rescue ProcessScale::SidecarMemoryLessThanProcessMemory, ProcessScale::InvalidProcess => e
    unprocessable!(e.message)
  end

  def stats
    process_stats, warnings = instances_reporters.stats_for_app(@process)
    add_warning_headers(warnings)

    render status: :ok, json: Presenters::V3::ProcessStatsPresenter.new(@process.type, process_stats)
  end

  private

  def find_process_and_space
    if app_nested?
      @process, app, @space = ProcessFetcher.fetch_for_app_by_type(app_guid: hashed_params[:app_guid], process_type: hashed_params[:type])

      app_not_found! unless app && permission_queryer.can_read_from_space?(@space.id, @space.organization_id)
      process_not_found! unless @process
    else
      @process, @space = ProcessFetcher.fetch(process_guid: hashed_params[:process_guid])
      process_not_found! unless @process && permission_queryer.can_read_from_space?(@space.id, @space.organization_id)
    end
  end

  def ensure_can_write
    unauthorized! unless permission_queryer.can_manage_apps_in_active_space?(@space.id)
    suspended! unless permission_queryer.is_space_active?(@space.id)
  end

  def process_not_found!
    resource_not_found!(:process)
  end

  def instances_reporters
    CloudController::DependencyLocator.instance.instances_reporters
  end
end
