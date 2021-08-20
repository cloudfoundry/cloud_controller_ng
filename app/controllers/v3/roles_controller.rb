require 'messages/role_create_message'
require 'messages/roles_list_message'
require 'messages/role_show_message'
require 'fetchers/role_list_fetcher'
require 'actions/role_create'
require 'actions/role_guid_populate'
require 'actions/role_delete'
require 'presenters/v3/role_presenter'
require 'decorators/include_role_user_decorator'
require 'decorators/include_role_organization_decorator'
require 'decorators/include_role_space_decorator'

class RolesController < ApplicationController
  def create
    message = RoleCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    role = message.space_guid ? create_space_role(message) : create_org_role(message)

    render status: :created, json: Presenters::V3::RolePresenter.new(role)
  rescue RoleCreate::Error => e
    unprocessable!(e)
  rescue UaaUnavailable
    raise CloudController::Errors::ApiError.new_from_details('UaaUnavailable')
  end

  def index
    message = RolesListMessage.from_params(query_params)
    unprocessable!(message.errors.full_messages) unless message.valid?

    RoleGuidPopulate.populate
    roles = RoleListFetcher.fetch(message, readable_roles, eager_loaded_associations: Presenters::V3::RolePresenter.associated_resources)

    decorators = []
    decorators << IncludeRoleUserDecorator if IncludeRoleUserDecorator.match?(message.include)
    decorators << IncludeRoleOrganizationDecorator if IncludeRoleOrganizationDecorator.match?(message.include)
    decorators << IncludeRoleSpaceDecorator if IncludeRoleSpaceDecorator.match?(message.include)

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::RolePresenter,
      paginated_result: SequelPaginator.new.get_page(roles, message.try(:pagination_options)),
      path: '/v3/roles',
      message: message,
      decorators: decorators,
    )
  end

  def show
    message = RoleShowMessage.from_params(query_params)
    unprocessable!(message.errors.full_messages) unless message.valid?

    decorators = []
    decorators << IncludeRoleUserDecorator if IncludeRoleUserDecorator.match?(message.include)
    decorators << IncludeRoleOrganizationDecorator if IncludeRoleOrganizationDecorator.match?(message.include)
    decorators << IncludeRoleSpaceDecorator if IncludeRoleSpaceDecorator.match?(message.include)

    role = readable_roles.first(guid: hashed_params[:guid])
    resource_not_found!(:role) unless role

    render status: :ok, json: Presenters::V3::RolePresenter.new(role, decorators: decorators)
  end

  def destroy
    role = readable_roles.first(guid: hashed_params[:guid])
    resource_not_found!(:role) unless role

    if role.for_space?
      org_guid = Space.find(guid: role.space_guid).organization.guid
      unauthorized! unless permission_queryer.can_update_space?(role.space_guid, org_guid)
    else
      unauthorized! unless permission_queryer.can_write_to_org?(role.organization_guid)

      if role.type == VCAP::CloudController::RoleTypes::ORGANIZATION_USER
        org = Organization.find(id: role.organization_id)
        no_space_role = Role.where(space_id: org.spaces.map(&:id), user_id: role.user_id).empty?
        unprocessable!('Cannot delete organization_user role while user has roles in spaces in that organization.') unless no_space_role
      end
    end

    role_owner = fetch_role_owner_with_name(role)
    delete_action = RoleDeleteAction.new(user_audit_info, role_owner)
    deletion_job = VCAP::CloudController::Jobs::DeleteActionJob.new(Role, role.guid, delete_action)
    pollable_job = Jobs::Enqueuer.new(deletion_job, queue: Jobs::Queues.generic).enqueue_pollable

    head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{pollable_job.guid}")
  end

  private

  def create_space_role(message)
    space = Space.find(guid: message.space_guid)
    unprocessable_space! unless space
    org = space.organization

    unprocessable_space! if permission_queryer.can_read_from_org?(org.guid) &&
      !permission_queryer.can_read_from_space?(message.space_guid, org.guid)

    unauthorized! unless permission_queryer.can_update_space?(message.space_guid, org.guid)

    user_guid = message.user_guid || lookup_user_guid_in_uaa(message.username, message.user_origin, creating_space_role: true)
    user = fetch_readable_user(user_guid)
    unprocessable_space_user! unless user

    RoleCreate.new(message, user_audit_info).create_space_role(
      type: message.type,
      user: user,
      space: space
    )
  end

  def create_org_role(message)
    org = Organization.find(guid: message.organization_guid)
    unprocessable_organization! unless org
    unauthorized! unless permission_queryer.can_write_to_org?(message.organization_guid)

    if message.user_guid
      user_guid = message.user_guid
      unprocessable_user! if user_in_db?(user_guid) && !user_is_readable?(user_guid)
    else
      user_guid = lookup_user_guid_in_uaa(message.username, message.user_origin)
      unprocessable_user! unless user_guid
    end

    user = User.first(guid: user_guid) || create_cc_user(user_guid)

    RoleCreate.new(message, user_audit_info).create_organization_role(
      type: message.type,
      user: user,
      organization: org
    )
  end

  def user_in_db?(user_guid)
    !User.where(guid: user_guid).empty?
  end

  def user_is_readable?(user_guid)
    !readable_users.where(guid: user_guid).empty?
  end

  def fetch_readable_user(user_guid)
    readable_users.first(guid: user_guid)
  end

  def fetch_role_owner_with_name(role)
    user = User.first(id: role.user_id)
    uaa_client = CloudController::DependencyLocator.instance.uaa_client
    UsernamePopulator.new(uaa_client).transform(user)
    user
  end

  def create_cc_user(user_guid)
    message = UserCreateMessage.new(guid: user_guid)
    UserCreate.new.create(message: message)
  end

  def readable_users
    current_user.readable_users(permission_queryer.can_read_globally?)
  end

  def readable_roles
    roles_in_visible_spaces = Role.filter(space_id: visible_space_ids)
    roles_in_visible_orgs = Role.filter(organization_id: visible_org_ids)

    roles_in_visible_spaces.union(roles_in_visible_orgs)
  end

  def visible_space_ids
    if permission_queryer.can_read_globally?
      Space.dataset.select(:id)
    else
      Space.user_visibility_filter(current_user)[:spaces__id]
    end
  end

  def visible_org_ids
    if permission_queryer.can_read_globally?
      Organization.dataset.select(:id)
    else
      Organization.user_visibility_filter(current_user)[:id]
    end
  end

  def unprocessable_space!
    unprocessable!('Invalid space. Ensure that the space exists and you have access to it.')
  end

  def unprocessable_organization!
    unprocessable!('Invalid organization. Ensure that the organization exists and you have access to it.')
  end

  def unprocessable_user!
    unprocessable!('Invalid user. Ensure that the user exists and you have access to it.')
  end

  def unprocessable_space_user!
    unprocessable!("Users cannot be assigned roles in a space if they do not have a role in that space's organization.")
  end

  def lookup_user_guid_in_uaa(username, given_origin, creating_space_role: false)
    FeatureFlag.raise_unless_enabled!(:set_roles_by_username)
    uaa_client = CloudController::DependencyLocator.instance.uaa_client

    origin = given_origin
    if given_origin.nil?
      origins = uaa_client.origins_for_username(username).sort

      if origins.length > 1
        unprocessable!(
          "Ambiguous user. User with username '#{username}' exists in the following origins: "\
          "#{origins.join(', ')}. Specify an origin to disambiguate."
        )
      end
      origin = origins[0]
    end

    guid = uaa_client.id_for_username(username, origin: origin)
    return guid if guid

    unprocessable_space_user! if creating_space_role
    unprocessable!("No user exists with the username '#{username}' and origin '#{origin}'.") if given_origin
    unprocessable!("No user exists with the username '#{username}'.")
  end
end
