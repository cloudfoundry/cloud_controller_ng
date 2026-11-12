require 'messages/service_account_create_message'
require 'presenters/v3/service_account_presenter'
require 'messages/service_account_update_message'
require 'messages/service_accounts_list_message'
require 'messages/apps_list_message'
require 'fetchers/app_list_fetcher'
require 'presenters/v3/app_presenter'
require 'repositories/service_account_event_repository'
require 'actions/service_account_creation_budget'

class ServiceAccountsController < ApplicationController
  def index
    message = ServiceAccountsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?
    dataset = ServiceAccountModel.eager(:organization, :entitled_spaces, :labels, :annotations)
    unless permission_queryer.can_read_globally?
      entitled = ServiceAccountModel.db[:service_account_space_entitlements].where(space_guid: permission_queryer.readable_space_guids_query).select(:service_account_guid)
      managed_orgs = current_user.managed_organizations_dataset.select(:id)
      dataset = dataset.where(Sequel.|({ guid: entitled }, { organization_id: managed_orgs }))
    end
    dataset = dataset.where(name: message.names) if message.requested?(:names)
    if message.requested?(:space_guids)
      dataset = dataset.where(guid: ServiceAccountModel.db[:service_account_space_entitlements].where(space_guid: message.space_guids).select(:service_account_guid))
    end
    dataset = dataset.where(organization_id: Organization.where(guid: message.organization_guids).select(:id)) if message.requested?(:organization_guids)
    render_list(dataset, message, Presenters::V3::ServiceAccountPresenter, '/v3/service_accounts')
  end

  def apps
    account = readable_account
    message = AppsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?
    spaces = account.entitled_spaces_dataset
    spaces = spaces.where(guid: permission_queryer.readable_space_guids_query) unless permission_queryer.can_read_globally?
    spaces = spaces.select_map(:guid)
    dataset = AppListFetcher.fetch(message, spaces).where(service_account_guid: account.guid)
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
    reuse = authorize_creation!(space, message)
    require_writable_space!(space)
    unprocessable!('Organization service account prefix is unset') unless space.organization.service_account_prefix

    account = nil
    previous_guid = nil
    ServiceAccountModel.db.transaction do
      space.organization.lock!
      unprocessable!('Organization is being deleted') if space.organization.deleting?
      limit = space.organization.quota_definition.total_service_accounts
      unprocessable!('Organization service account quota exceeded') if limit != -1 && ServiceAccountModel.where(organization_id: space.organization_id).count >= limit
      ServiceAccountCreationBudget.consume(current_user, exempt: permission_queryer.can_write_globally?) do
        previous_guid = release_reservation_for_reuse(space, message) if reuse
        account = ServiceAccountModel.create(name: message.name, space: space)
        apply_metadata(account, message)
        Repositories::ServiceAccountEventRepository.record(account, 'create', user_audit_info, reuse_name: reuse, previous_account_guid: previous_guid)
      end
    end
    add_warning_headers(['Reusing this identity can inherit external grants and accept still-valid old certificates.']) if reuse
    render status: :created, json: Presenters::V3::ServiceAccountPresenter.new(account)
  rescue Sequel::ValidationFailed => e
    raise CloudController::Errors::V3::ApiError.new_from_details('ServiceAccountNameReserved') if e.message.include?('is already reserved')

    unprocessable!(e.message)
  end

  def update
    account = readable_account
    authorize_account_management!(account)
    message = ServiceAccountUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?
    job = nil
    account.db.transaction do
      account.lock!
      authorize_account_management!(account)
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
    authorize_account_management!(account)
    require_provisioning!
    job = nil
    account.db.transaction do
      account.lock!
      authorize_account_management!(account)
      lifecycle_conflict!('service account is still assigned or in use') if account.in_use?
      reject_active_operation!(account)
      account.update(enabled: false, status: 'deleting')
      job = enqueue_lifecycle(account, 'delete')
      Repositories::ServiceAccountEventRepository.record(account, 'delete', user_audit_info)
    end
    head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{job.guid}")
  end

  private

  def release_reservation_for_reuse(space, message)
    lifecycle_conflict!('live account name is already in use') if ServiceAccountModel.where(organization_id: space.organization_id, name: message.name).any?
    history = ServiceAccountModel.db[:service_account_name_deletions].
              where(organization_guid: space.organization.guid, name: message.name).order(Sequel.desc(:deleted_at)).first
    ServiceAccountModel.db[:service_account_names].where(organization_id: space.organization_id, name: message.name).delete
    history&.fetch(:account_guid)
  end

  def authorize_creation!(space, message)
    reuse = message.reuse_name == true
    manager = permission_queryer.can_write_globally? || space.organization.managers_dataset.where(users__id: current_user.id).any?
    unauthorized! if reuse && !manager
    unauthorized! unless permission_queryer.can_write_to_active_space?(space.id) || (reuse && manager)
    reuse
  end

  def org_manager?(account)
    permission_queryer.can_write_globally? || account.organization.managers_dataset.where(users__id: current_user.id).any?
  end

  def developer?(space)
    space.developers_dataset.where(users__id: current_user.id).any?
  end

  def authorize_account_management!(account)
    unauthorized! unless org_manager?(account) || account.entitled_spaces_dataset.all.any? { |space| developer?(space) && space.active? }
    require_writable_org!(account.organization)
  end

  public

  def spaces
    account = readable_account
    render status: :ok, json: { data: account.entitled_spaces.map { |space| { guid: space.guid } } }
  end

  def entitle
    account = readable_account
    unprocessable!('Organization service account prefix is unset') unless account.organization.service_account_prefix
    data = entitlement_guids
    account.db.transaction do
      account.lock!
      lifecycle_conflict!('service account is being deleted') if account.status == 'deleting'
      require_writable_org!(account.organization)
      data.each do |guid|
        space = Space.first(guid: guid)
        unprocessable!('Space must belong to the account organization') unless space && space.organization_id == account.organization_id
        unprocessable!('Space is being deleted') if space.deleting?
        unauthorized! unless can_entitle?(account, space)
        require_writable_space!(space)
        account.add_entitled_space(space) unless account.entitled_spaces_dataset.where(spaces__guid: space.guid).any?
        Repositories::ServiceAccountEventRepository.record(account, 'entitle', user_audit_info, space_guid: space.guid)
      end
    end
    spaces
  end

  def unentitle
    account = readable_account
    account.db.transaction do
      account.lock!
      require_writable_org!(account.organization)
      space = account.entitled_spaces_dataset.where(spaces__guid: hashed_params[:space_guid]).first
      resource_not_found!(:space) unless space
      unauthorized! unless org_manager?(account) || developer?(space)
      require_writable_space!(space)
      lifecycle_conflict!('cannot revoke the last entitlement; delete the account instead') if !org_manager?(account) && account.entitled_spaces_dataset.one?
      lifecycle_conflict!('service account is still assigned or in use in this space') if account.in_use_in_space?(space)
      account.remove_entitled_space(space)
      Repositories::ServiceAccountEventRepository.record(account, 'unentitle', user_audit_info, space_guid: space.guid)
    end
    render status: :ok, json: { data: account.entitled_spaces_dataset.all.map { |space| { guid: space.guid } } }
  end

  private

  def can_entitle?(account, space)
    org_manager?(account) || (developer?(space) && account.entitled_spaces_dataset.all.any? { |source| source.active? && developer?(source) })
  end

  def entitlement_guids
    data = hashed_params[:body]['data'] || hashed_params[:body][:data]
    unprocessable!('Data must be an array of space GUIDs') unless data.is_a?(Array)
    data.map do |entry|
      unprocessable!('Data must be an array of space GUIDs') unless entry.is_a?(Hash) && (entry['guid'] || entry[:guid]).is_a?(String)
      entry['guid'] || entry[:guid]
    end
  end

  def readable?(account)
    permission_queryer.can_read_globally? || org_manager?(account) ||
      account.entitled_spaces.any? { |space| permission_queryer.can_read_from_space?(space.id, space.organization_id) }
  end

  def require_provisioning!
    lifecycle_conflict!('service accounts are not enabled') unless Config.config.get(:service_accounts_enabled) == true
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
    resource_not_found!(:service_account) unless account && readable?(account)
    account
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
