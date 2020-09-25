require 'actions/service_credential_binding_create'
require 'actions/service_credential_binding_delete'
require 'fetchers/service_credential_binding_fetcher'
require 'fetchers/service_credential_binding_list_fetcher'
require 'presenters/v3/service_credential_binding_presenter'
require 'presenters/v3/service_credential_binding_details_presenter'
require 'messages/service_credential_binding_list_message'
require 'messages/service_credential_binding_show_message'
require 'messages/service_credential_binding_create_message'
require 'decorators/include_binding_app_decorator'
require 'decorators/include_binding_service_instance_decorator'
require 'jobs/v3/create_service_credential_binding_job'

class ServiceCredentialBindingsController < ApplicationController
  def index
    message = ServiceCredentialBindingListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    results = list_fetcher.fetch(space_guids: space_guids, message: message)

    presenter = Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::ServiceCredentialBindingPresenter,
      paginated_result: SequelPaginator.new.get_page(results, message.try(:pagination_options)),
      path: '/v3' + service_credential_bindings_path,
      message: message,
      decorators: decorators(message)
    )

    render status: :ok, json: presenter
  end

  def show
    message = ServiceCredentialBindingShowMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    ensure_service_credential_binding_is_accessible!

    render status: :ok, json: serialized(message)
  end

  def create
    message = ServiceCredentialBindingCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    service_instance = VCAP::CloudController::ServiceInstance.first(guid: message.service_instance_guid)
    resource_not_accessible!('service instance', message.service_instance_guid) unless can_access_resource?(service_instance)

    app = VCAP::CloudController::AppModel.first(guid: message.app_guid)
    resource_not_accessible!('app', message.app_guid) unless can_access_resource?(app)
    unauthorized! unless can_write_to_space?(app.space)

    action = V3::ServiceCredentialBindingCreate.new(user_audit_info, message.audit_hash)
    binding = action.precursor(service_instance, app: app, name: message.name, volume_mount_services_enabled: volume_services_enabled?)

    case service_instance
    when ManagedServiceInstance
      pollable_job_guid = enqueue_bind_job(binding.guid, message)
      head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{pollable_job_guid}")
    when UserProvidedServiceInstance
      action.bind(binding)
      render status: :created, json: Presenters::V3::ServiceCredentialBindingPresenter.new(binding).to_hash
    end
  rescue V3::ServiceCredentialBindingCreate::UnprocessableCreate => e
    unprocessable!(e.message)
  rescue V3::ServiceCredentialBindingCreate::Unimplemented
    head :not_implemented
  end

  def destroy
    not_found! unless service_credential_binding.present?
    unauthorized! unless can_write_to_space?(binding_space)

    V3::ServiceCredentialBindingDelete.new.delete(service_credential_binding)
    head :no_content
  rescue V3::ServiceCredentialBindingDelete::NotImplementedError
    head :not_implemented
  end

  def details
    ensure_service_credential_binding_is_accessible!
    not_found! unless can_read_secrets_in_the_binding_space?

    credentials = if service_credential_binding[:type] == 'key' && service_credential_binding.credhub_reference?
                    fetch_credentials_value(service_credential_binding.credhub_reference)
                  else
                    service_credential_binding.credentials
                  end

    details = Presenters::V3::ServiceCredentialBindingDetailsPresenter.new(
      binding: service_credential_binding,
      credentials: credentials
    ).to_hash

    render status: :ok, json: details
  end

  def parameters
    ensure_service_credential_binding_is_accessible!

    fetcher = ServiceBindingRead.new
    parameters = fetcher.fetch_parameters(service_credential_binding)

    render status: :ok, json: parameters
  rescue ServiceBindingRead::NotSupportedError
    raise CloudController::Errors::ApiError.
      new_from_details('ServiceFetchBindingParametersNotSupported').
      with_response_code(502)
  rescue LockCheck::ServiceBindingLockedError => e
    raise CloudController::Errors::ApiError.new_from_details('AsyncServiceBindingOperationInProgress', e.service_binding.app.name, e.service_binding.service_instance.name)
  end

  private

  def enqueue_bind_job(binding_guid, message)
    bind_job = VCAP::CloudController::V3::CreateServiceCredentialBindingJob.new(
      binding_guid,
      user_audit_info: user_audit_info,
      audit_hash: message.audit_hash,
      parameters: message.parameters
    )
    pollable_job = Jobs::Enqueuer.new(bind_job, queue: Jobs::Queues.generic).enqueue_pollable
    pollable_job.guid
  end

  def resource_not_accessible!(resource, guid)
    unprocessable!("The #{resource} could not be found: '#{guid}'")
  end

  def can_access_resource?(resource)
    resource.present? && can_read_from_space?(resource.space)
  end

  def can_write_to_space?(space)
    permission_queryer.can_write_to_space?(space.guid)
  end

  AVAILABLE_DECORATORS = [
    IncludeBindingAppDecorator,
    IncludeBindingServiceInstanceDecorator
  ].freeze

  def decorators(message)
    AVAILABLE_DECORATORS.select { |d| d.match?(message.include) }
  end

  def config
    @config ||= VCAP::CloudController::Config.config
  end

  def volume_services_enabled?
    config.get(:volume_services_enabled)
  end

  def uaa_client
    @uaa_client ||= UaaClient.new(
      uaa_target: config.get(:uaa, :internal_url),
      client_id: config.get(:cc_service_key_client_name),
      secret: config.get(:cc_service_key_client_secret),
      ca_file: config.get(:uaa, :ca_file),
    )
  end

  def credhub_client
    # TODO: use the credhub client provided by `DependencyLocator`
    @credhub_client ||= Credhub::Client.new(config.get(:credhub_api, :internal_url), uaa_client)
  end

  def fetch_credentials_value(name)
    credhub_client.get_credential_by_name(name)
  rescue => e
    service_unavailable!("Fetching credentials from CredHub failed; reason: #{e.message}")
  end

  def service_credential_binding
    @service_credential_binding ||= fetcher.fetch(hashed_params[:guid], space_guids: space_guids)
  end

  def space_guids
    if permission_queryer.can_read_globally?
      :all
    else
      permission_queryer.readable_space_guids
    end
  end

  def pagination_options
    query_params_with_order_by = query_params.reverse_merge(order_by: :created_at)
    ListMessage.from_params(query_params_with_order_by, []).pagination_options
  end

  def serialized(message)
    Presenters::V3::ServiceCredentialBindingPresenter.new(service_credential_binding, decorators: decorators(message)).to_hash
  end

  def ensure_service_credential_binding_is_accessible!
    not_found! unless service_credential_binding_exists?
  end

  def not_found!
    resource_not_found!(:service_credential_binding)
  end

  def service_credential_binding_exists?
    !!service_credential_binding
  end

  def can_read_secrets_in_the_binding_space?
    permission_queryer.can_read_secrets_in_space?(binding_space.guid, binding_org.guid)
  end

  def can_read_from_space?(space)
    permission_queryer.can_read_from_space?(space.guid, space.organization.guid)
  end

  def binding_space
    service_credential_binding.space
  end

  def binding_org
    service_credential_binding.space.organization
  end

  def list_fetcher
    @list_fetcher ||= VCAP::CloudController::ServiceCredentialBindingListFetcher.new
  end

  def fetcher
    @fetcher ||= VCAP::CloudController::ServiceCredentialBindingFetcher.new
  end

  def query_params
    request.query_parameters.with_indifferent_access
  end
end
