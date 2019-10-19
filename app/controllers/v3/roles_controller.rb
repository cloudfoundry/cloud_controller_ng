require 'messages/role_create_message'
require 'actions/role_create'
require 'presenters/v3/role_presenter'

class RolesController < ApplicationController
  def create
    message = RoleCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    user_guid = message.user_guid || guid_for_uaa_user(message.user_name, message.user_origin)
    user = readable_users.first(guid: user_guid)
    unprocessable_user! unless user

    role = if message.space_guid
             space = Space.find(guid: message.space_guid)
             unprocessable_space! unless space
             org = space.organization

             unprocessable_space! if permission_queryer.can_read_from_org?(org.guid) &&
               !permission_queryer.can_read_from_space?(message.space_guid, org.guid)

             unauthorized! unless permission_queryer.can_update_space?(message.space_guid, org.guid)

             RoleCreate.create_space_role(type: message.type, user: user, space: space)
           else
             org = Organization.find(guid: message.organization_guid)
             unprocessable_organization! unless org
             unauthorized! unless permission_queryer.can_write_to_org?(message.organization_guid)

             RoleCreate.create_organization_role(type: message.type, user: user, organization: org)
           end

    render status: :created, json: Presenters::V3::RolePresenter.new(role)
  rescue RoleCreate::Error => e
    unprocessable!(e)
  end

  private

  def readable_users
    User.readable_users_for_current_user(permission_queryer.can_read_secrets_globally?, current_user)
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

  def guid_for_uaa_user(username, given_origin)
    uaa_client = CloudController::DependencyLocator.instance.uaa_client

    origin = if given_origin
               given_origin
             else
               origins = uaa_client.origins_for_username(username)

               if origins.length > 1
                 unprocessable!(
                   "Ambiguous user. User with username '#{username}' exists in the following origins: "\
                   "#{origins.join(', ')}. Specify an origin to disambiguate."
                 )
               end

               origins[0]
             end

    guid = uaa_client.id_for_username(username, origin: origin)

    unless guid
      if given_origin
        unprocessable!("No user exists with the username '#{username}' and origin '#{origin}'.")
      else
        unprocessable!("No user exists with the username '#{username}'.")
      end
    end

    guid
  end
end
