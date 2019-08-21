require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class UserPresenter < BasePresenter
    def to_hash
      {
          guid: user.guid,
          created_at: user.created_at,
          updated_at: user.updated_at,
          username: user.username,
          presentation_name: user.username || user.guid,
          origin: user.origin,
          links: build_links
      }
    end

    private

    def user
      @resource
    end

    def build_links
      url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new
      links = {
          self: {
              href: url_builder.build_url(path: "/v3/users/#{user.guid}")
          }
      }
      links
    end
  end
end
