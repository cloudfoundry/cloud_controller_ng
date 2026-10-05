require 'messages/service_account_create_message'
require 'presenters/v3/service_account_presenter'
require 'messages/service_account_update_message'
require 'messages/service_accounts_list_message'
require 'messages/apps_list_message'
require 'fetchers/app_list_fetcher'
require 'presenters/v3/app_presenter'
require 'repositories/service_account_event_repository'

class ServiceAccountsController < ApplicationController
  def index
    message = ServiceAccountsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?
    dataset = ServiceAccountModel.dataset
    dataset = dataset.where(space_guid: permission_queryer.readable_space_guids_query) unless permission_queryer.can_read_globally?
    dataset = dataset.where(name: message.names) if message.requested?(:names)
    dataset = dataset.where(space_guid: message.space_guids) if message.requested?(:space_guids)
    render_list(dataset, message, Presenters::V3::ServiceAccountPresenter, '/v3/service_accounts')
  end

  def apps
    account = readable_account
    message = AppsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?
    dataset = AppListFetcher.fetch(message, [account.space_guid]).where(service_account_guid: account.guid)
    render_list(dataset, message, Presenters::V3::AppPresenter, "/v3/service_accounts/#{account.guid}/apps")
  end

  def show
    account = readable_account

    render status: :ok, json: Presenters::V3::ServiceAccountPresenter.new(account)
  end

  def create
    message = ServiceAccountCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    space = Space.where(guid: message.space_guid).first
    unprocessable!('Space not found') unless space && permission_queryer.can_read_from_space?(space.id, space.organization_id)
    authorize_management!(space)

    account = nil
    ServiceAccountModel.db.transaction do
      account = ServiceAccountModel.create(name: message.name, space: space)
      apply_metadata(account, message)
      Repositories::ServiceAccountEventRepository.record(account, 'create', user_audit_info)
    end
    render status: :created, json: Presenters::V3::ServiceAccountPresenter.new(account)
  rescue Sequel::ValidationFailed => e
    raise CloudController::Errors::V3::ApiError.new_from_details('ServiceAccountNameReserved') if e.message.include?('is already reserved')

    unprocessable!(e.message)
  end

  def update
    account = readable_account
    authorize_management!(account.space)
    message = ServiceAccountUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?
    job = nil
    account.db.transaction do
      account.lock!
      apply_metadata(account, message)
      if message.requested?(:enabled)
        require_provisioning!
        reject_active_operation!(account)
        account.update(enabled: message.enabled, status: 'reconciling')
        job = enqueue_lifecycle(account, message.enabled ? 'provision' : 'disable')
      end
      Repositories::ServiceAccountEventRepository.record(account, 'update', user_audit_info, message.audit_hash)
    end
    return head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{job.guid}") if job

    render status: :ok, json: Presenters::V3::ServiceAccountPresenter.new(account.reload)
  end

  def destroy
    account = readable_account
    authorize_management!(account.space)
    require_provisioning!
    job = nil
    account.db.transaction do
      account.lock!
      lifecycle_conflict!('service account is still assigned or in use') if account.in_use?
      reject_active_operation!(account)
      account.update(enabled: false, status: 'deleting')
      job = enqueue_lifecycle(account, 'delete')
      Repositories::ServiceAccountEventRepository.record(account, 'delete', user_audit_info)
    end
    head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{job.guid}")
  end

  private

  def require_provisioning!
    lifecycle_conflict!('service account provisioning is not enabled') unless Config.config.get(:service_account_provisioning_enabled) == true
  end

  def reject_active_operation!(account)
    return unless PollableJobModel.where(resource_guid: account.guid, resource_type: 'service_account', state: %w[PROCESSING POLLING]).any?

    lifecycle_conflict!('service account operation is already in progress')
  end

  def lifecycle_conflict!(detail)
    raise CloudController::Errors::V3::ApiError.new_from_details('ServiceAccountAssignmentConflict', detail)
  end

  def enqueue_lifecycle(account, operation)
    Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(Jobs::V3::ServiceAccountProvision.new(account.guid, operation: operation))
  end

  def readable_account
    account = ServiceAccountModel.first(guid: hashed_params[:guid])
    resource_not_found!(:service_account) unless account && permission_queryer.can_read_from_space?(account.space.id, account.space.organization_id)
    account
  end

  def authorize_management!(space)
    unauthorized! unless permission_queryer.can_write_globally? || space.managers_dataset.where(id: current_user.id).any?
    require_writable_space!(space)
  end

  def apply_metadata(account, message)
    account.update(description: message.description || '') if message.requested?(:description)
    LabelsUpdate.update(account, message.labels, ServiceAccountLabelModel)
    AnnotationsUpdate.update(account, message.annotations, ServiceAccountAnnotationModel)
  end

  def render_list(dataset, message, presenter, path)
    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: presenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.pagination_options),
      path: path, message: message
    )
  end
end
