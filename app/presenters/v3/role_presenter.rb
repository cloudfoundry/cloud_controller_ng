require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class RolePresenter < BasePresenter
    def to_hash
      {
        guid: role.guid,
        created_at: role.created_at,
        updated_at: role.updated_at,
        type: role.type,
        relationships: {
          user: {
            data: { guid: role.user_guid }
          },
          space: {
            data: { guid: role.space_guid }
          }
        },
        links: build_links
      }
    end

    private

    def role
      @resource
    end

    def build_links
      url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new
      links = {
        self: {
          href: url_builder.build_url(path: "/v3/roles/#{role.guid}"),
        },
        user: {
          href: url_builder.build_url(path: "/v3/users/#{role.user_guid}"),
        },
        space: {
          href: url_builder.build_url(path: "/v3/spaces/#{role.space_guid}")
        }
      }
      links
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
