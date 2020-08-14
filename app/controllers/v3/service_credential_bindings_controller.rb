require 'fetchers/service_credential_binding_fetcher'
require 'fetchers/service_credential_binding_list_fetcher'
require 'presenters/v3/service_credential_binding_presenter'
require 'messages/service_credential_bindings_list_message'

class ServiceCredentialBindingsController < ApplicationController
  def index
    message = ServiceCredentialBindingsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    results = list_fetcher.fetch(space_guids: space_guids, message: message)

    presenter = Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::ServiceCredentialBindingPresenter,
      paginated_result: SequelPaginator.new.get_page(results, pagination_options),
      path: '/v3' + service_credential_bindings_path,
      message: message,
    )

    render status: :ok, json: presenter
  end

  def show
    ensure_service_credential_binding_is_accessible!
    render status: :ok, json: serialized
  end

  private

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

  def serialized
    Presenters::V3::ServiceCredentialBindingPresenter.new(service_credential_binding).to_hash
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
