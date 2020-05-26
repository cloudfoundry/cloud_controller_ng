require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class RolePresenter < BasePresenter
    class << self
      def associated_resources
        [:user, :space, :organization]
      end
    end

    def to_hash
      hash = {
        guid: role.guid,
        created_at: role.created_at,
        updated_at: role.updated_at,
        type: role.type,
        relationships: build_relationships,
        links: build_links
      }
      @decorators.reduce(hash) { |memo, d| d.decorate(memo, [role]) }
    end

    private

    def role
      @resource
    end

    def build_links
      links = {
        self: {
          href: url_builder.build_url(path: "/v3/roles/#{role.guid}"),
        },
        user: {
          href: url_builder.build_url(path: "/v3/users/#{CGI.escape(role.user_guid)}"),
        },
      }
      if VCAP::CloudController::RoleTypes::SPACE_ROLES.include? role.type
        links[:space] = { href: url_builder.build_url(path: "/v3/spaces/#{role.space_guid}") }
      else
        links[:organization] = { href: url_builder.build_url(path: "/v3/organizations/#{role.organization_guid}") }
      end
      links
    end

    def build_relationships
      relationships = {
        user: {
          data: { guid: role.user_guid }
        },
      }

      if VCAP::CloudController::RoleTypes::SPACE_ROLES.include? role.type
        relationships[:space] = { data: { guid: role.space_guid } }
        relationships[:organization] = { data: nil }
      else
        relationships[:organization] = { data: { guid: role.organization_guid } }
        relationships[:space] = { data: nil }
      end
      relationships
    end

    def username
      return nil unless @uaa_users[user.guid]

      @uaa_users[user.guid]['username']
    end

    def origin
      return nil unless @uaa_users[user.guid]

      @uaa_users[user.guid]['origin']
    end
  end
end
