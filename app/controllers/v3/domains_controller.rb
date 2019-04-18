require 'messages/domain_create_message'
require 'messages/domains_list_message'
require 'presenters/v3/domain_presenter'
require 'actions/domain_create'
require 'fetchers/domain_fetcher'

class DomainsController < ApplicationController
  def index
    message = DomainsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    org_guids = permission_queryer.readable_org_guids_for_domains
    dataset = DomainFetcher.fetch_all(org_guids)

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::DomainPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: '/v3/domains',
      message: message,
      extra_presenter_args: { visible_org_guids: permission_queryer.readable_org_guids }
    )
  end

  def create
    message = DomainCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    shared_org_objects = []
    if create_scoped_domain_request?(message)
      check_create_scoped_domain_permissions!(message)
      shared_org_objects = verify_shared_organizations_guids!(message)
    else
      unauthorized! unless permission_queryer.can_write_globally?
    end

    domain = DomainCreate.new.create(message: message, shared_organizations: shared_org_objects)

    render status: :created, json: Presenters::V3::DomainPresenter.new(domain, visible_org_guids: permission_queryer.readable_org_guids)
  rescue DomainCreate::Error => e
    unprocessable!(e)
  end

  def show
    readable_org_guids = permission_queryer.readable_org_guids_for_domains
    domain = DomainFetcher.fetch(
      readable_org_guids,
      hashed_params['guid']
    )

    domain_not_found! unless domain

    render status: :ok, json: Presenters::V3::DomainPresenter.new(domain, visible_org_guids: permission_queryer.readable_org_guids)
  end

  private

  def check_create_scoped_domain_permissions!(message)
    unprocessable_org!(message.organization_guid) unless Organization.find(guid: message.organization_guid)

    unauthorized! unless permission_queryer.can_write_to_org?(message.organization_guid)

    FeatureFlag.raise_unless_enabled!(:private_domain_creation) unless permission_queryer.can_write_globally?
  end

  def verify_shared_organizations_guids!(message)
    organizations = Organization.where(guid: message.shared_organizations_guids).all

    unless organizations.length == message.shared_organizations_guids.length
      unprocessable!("Organization with guid '#{find_missing_guid(organizations, message.shared_organizations_guids)}' does not exist, or you do not have access to it.")
    end

    organizations.each do |org|
      unprocessable!("Organization with guid '#{org.guid}' either does not exist, or you do not have access to it.") unless permission_queryer.can_read_from_org?(org.guid)
      unprocessable!("You do not have sufficient permissions for organization '#{org.name}' to share domain.") unless permission_queryer.can_write_to_org?(org.guid)
    end

    unprocessable!('Domain cannot be shared with owning organization.') if message.shared_organizations_guids.include?(message.organization_guid)

    organizations
  end

  def create_scoped_domain_request?(message)
    message.requested?(:relationships)
  end

  def unprocessable_org!(org_guid)
    unprocessable!("Organization with guid '#{org_guid}' does not exist or you do not have access to it.")
  end

  def domain_not_found!
    resource_not_found!(:domain)
  end

  def find_missing_guid(db_organizations, message_shared_org_guids)
    (message_shared_org_guids - db_organizations.map(&:guid)).first
  end
end
