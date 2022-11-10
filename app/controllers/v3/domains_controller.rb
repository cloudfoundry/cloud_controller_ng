require 'messages/domain_create_message'
require 'messages/domains_list_message'
require 'messages/domain_show_message'
require 'messages/domain_update_message'
require 'messages/domain_update_shared_orgs_message'
require 'messages/domain_delete_shared_org_message'
require 'presenters/v3/domain_presenter'
require 'presenters/v3/domain_shared_orgs_presenter'
require 'actions/domain_create'
require 'actions/domain_delete'
require 'actions/domain_update'
require 'actions/domain_update_shared_orgs'
require 'actions/domain_delete_shared_org'
require 'fetchers/domain_fetcher'

class DomainsController < ApplicationController
  def index
    message = DomainsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    dataset = DomainFetcher.fetch(message, permission_queryer.readable_org_guids_for_domains_query)

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::DomainPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: '/v3/domains',
      message: message,
      extra_presenter_args: presenter_args
    )
  end

  def create
    message = DomainCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    shared_org_objects = []
    if create_private_domain_request?(message)
      check_create_private_domain_permissions!(message)
      shared_org_objects = verify_shared_organizations_guids!(message, message.organization_guid)
    else
      unauthorized! unless permission_queryer.can_write_globally?
    end

    if message.router_group_guid.present? && fetch_router_group(message.router_group_guid).nil?
      unprocessable!("Router group with guid '#{message.router_group_guid}' not found.")
    end
    domain = DomainCreate.new.create(message: message, shared_organizations: shared_org_objects)

    render status: :created, json: Presenters::V3::DomainPresenter.new(domain, **presenter_args)
  rescue DomainCreate::Error => e
    unprocessable!(e)
  end

  def check_routes
    message = DomainShowMessage.new({ guid: hashed_params['guid'] })
    unprocessable!(message.errors.full_messages) unless message.valid?

    domain = find_domain(message)
    domain_not_found! unless domain

    check_route_params = to_route_list_params(query_params, domain)
    message = RoutesListMessage.from_params(check_route_params)
    unprocessable!(message.errors.full_messages) unless message.valid?

    dataset = RouteFetcher.fetch(message, omniscient: true)
    matching_route = false
    if dataset.any?
      matching_route = true
    end

    render status: :ok, json: { matching_route: matching_route }
  end

  def show
    message = DomainShowMessage.new({ guid: hashed_params['guid'] })
    unprocessable!(message.errors.full_messages) unless message.valid?

    domain = find_domain(message)
    domain_not_found! unless domain

    render status: :ok, json: Presenters::V3::DomainPresenter.new(domain, **presenter_args)
  end

  def update
    message = DomainUpdateMessage.new(hashed_params[:body].merge({ guid: hashed_params['guid'] }))
    unprocessable!(message.errors.full_messages) unless message.valid?

    domain = find_domain(message)
    domain_not_found! unless domain

    unauthorized! unless can_write_to_active_org?(domain.owning_organization_id)
    suspended! unless org_active?(domain.owning_organization_id)

    domain = DomainUpdate.new.update(domain: domain, message: message)

    render status: :ok, json: Presenters::V3::DomainPresenter.new(domain, **presenter_args)
  end

  def destroy
    message = DomainShowMessage.new({ guid: hashed_params['guid'] })
    unprocessable!(message.errors.full_messages) unless message.valid?

    domain = find_domain(message)
    domain_not_found! unless domain

    unauthorized! unless can_write_to_active_org?(domain.owning_organization_id)
    suspended! unless org_active?(domain.owning_organization_id)

    unprocessable!('This domain is shared with other organizations. Unshare before deleting.') unless domain.shared_organizations.empty?

    delete_action = DomainDelete.new
    deletion_job = VCAP::CloudController::Jobs::DeleteActionJob.new(Domain, domain.guid, delete_action)
    pollable_job = Jobs::Enqueuer.new(deletion_job, queue: Jobs::Queues.generic).enqueue_pollable

    head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{pollable_job.guid}")
  end

  def update_shared_orgs
    message = DomainUpdateSharedOrgsMessage.new(guid: hashed_params['guid'], data: hashed_params[:body][:data])
    unprocessable!(message.errors.full_messages) unless message.valid?

    domain = find_domain(message)
    domain_not_found! unless domain

    unauthorized! unless can_write_to_active_org?(domain.owning_organization_id)
    suspended! unless org_active?(domain.owning_organization_id)

    shared_orgs = verify_shared_organizations_guids!(message, domain.owning_organization_guid)

    unprocessable!('Domains cannot be shared with other organizations unless they are scoped to an organization.') unless domain.private?

    DomainUpdateSharedOrgs.update(domain: domain, shared_organizations: shared_orgs)
    render status: :ok, json: Presenters::V3::DomainSharedOrgsPresenter.new(domain, **presenter_args)
  end

  def delete_shared_org
    message = DomainDeleteSharedOrgMessage.new(guid: hashed_params[:guid], org_guid: hashed_params[:org_guid])
    unprocessable!(message.errors.full_messages) unless message.valid?

    domain = find_domain(message)
    domain_not_found! unless domain

    shared_org = Organization.find(guid: message.org_guid)
    unprocessable_org!(message.org_guid) unless shared_org

    check_unshare_domain_permissions!(domain.owning_organization_id, shared_org.id)

    unprocessable_org!(message.org_guid) unless permission_queryer.can_read_from_org?(shared_org.id)

    DomainDeleteSharedOrg.delete(domain: domain, shared_organization: shared_org)
    head :no_content
  rescue DomainDeleteSharedOrg::OrgError
    unprocessable!("Unable to unshare domain from organization with name '#{shared_org.name}'. Ensure the domain is shared to this organization.")
  rescue DomainDeleteSharedOrg::RouteError
    unprocessable!('This domain has associated routes in this organization. Delete the routes before unsharing.')
  end

  private

  def to_route_list_params(query_params, domain)
    check_route_params = { 'domain_guids' => domain.guid, 'paths' => '', 'hosts' => '', 'ports' => 0 }
    check_route_params['paths'] = query_params[:path] if query_params.key?(:path)
    check_route_params['hosts'] = query_params[:host] if query_params.key?(:host)
    check_route_params['ports'] = query_params[:port] if query_params.key?(:port)
    check_route_params
  end

  def find_domain(message)
    domain = DomainFetcher.fetch(
      message,
      permission_queryer.readable_org_guids_for_domains_query
    ).first

    domain
  end

  def check_unshare_domain_permissions!(owning_org_id, shared_org_id)
    owning_org_writable = can_write_to_active_org?(owning_org_id)
    return if owning_org_writable && org_active?(owning_org_id)

    shared_org_writable = can_write_to_active_org?(shared_org_id)
    return if shared_org_writable && org_active?(shared_org_id)

    unauthorized! unless owning_org_writable || shared_org_writable
    suspended!
  end

  def check_create_private_domain_permissions!(message)
    org = Organization.find(guid: message.organization_guid)
    unprocessable_org!(message.organization_guid) unless org

    unauthorized! unless can_write_to_active_org?(org.id)
    suspended! unless org_active?(org.id)

    FeatureFlag.raise_unless_enabled!(:private_domain_creation) unless permission_queryer.can_write_globally?
  end

  def verify_shared_organizations_guids!(message, owning_org_guid)
    organizations = Organization.where(guid: message.shared_organizations_guids).all

    unless organizations.length == message.shared_organizations_guids.length
      unprocessable!("Organization with guid '#{find_missing_guid(organizations, message.shared_organizations_guids)}' does not exist, or you do not have access to it.")
    end

    organizations.each do |org|
      unprocessable!("Organization with guid '#{org.guid}' either does not exist, or you do not have access to it.") unless permission_queryer.can_read_from_org?(org.id)
      unprocessable!("You do not have sufficient permissions for organization '#{org.name}' to share domain.") unless can_write_to_active_org?(org.id)
      unprocessable!("Organization '#{org.name}' is suspended.") unless org_active?(org.id)
    end

    unprocessable!('Domain cannot be shared with owning organization.') if message.shared_organizations_guids.include?(owning_org_guid)

    organizations
  end

  def create_private_domain_request?(message)
    message.requested?(:relationships)
  end

  def unprocessable_org!(org_guid)
    unprocessable!("Organization with guid '#{org_guid}' does not exist or you do not have access to it.")
  end

  def can_write_to_active_org?(org_id)
    permission_queryer.can_write_to_active_org?(org_id)
  end

  def org_active?(org_id)
    permission_queryer.is_org_active?(org_id)
  end

  def domain_not_found!
    resource_not_found!(:domain)
  end

  def find_missing_guid(db_organizations, message_shared_org_guids)
    (message_shared_org_guids - db_organizations.map(&:guid)).first
  end

  def fetch_router_group(router_group_guid)
    routing_client = CloudController::DependencyLocator.instance.routing_api_client
    service_unavailable!('The Routing API is disabled.') unless routing_client.enabled?

    routing_client.router_group(router_group_guid)
  rescue RoutingApi::RoutingApiUnavailable
    service_unavailable!('The Routing API is currently unavailable. Please try again later.')
  rescue UaaUnavailable, RoutingApi::UaaUnavailable
    service_unavailable!('Communicating with the Routing API failed because UAA is currently unavailable. Please try again later.')
  end

  def presenter_args
    if permission_queryer.can_read_globally?
      { all_orgs_visible: true }
    else
      { visible_org_guids_query: permission_queryer.readable_org_guids_query }
    end
  end
end
