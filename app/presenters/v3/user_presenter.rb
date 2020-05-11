require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'
require 'presenters/helpers/censorship'

module VCAP::CloudController::Presenters::V3
  class UserPresenter < BasePresenter
    include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

    def initialize(
      resource,
      show_secrets: false,
      censored_message: VCAP::CloudController::Presenters::Censorship::REDACTED_CREDENTIAL,
      uaa_users: {}
    )
      @uaa_users = uaa_users
      super(resource, show_secrets: show_secrets, censored_message: censored_message, decorators: [])
    end

    def to_hash
      {
        guid: user.guid,
        created_at: user.created_at,
        updated_at: user.updated_at,
        username: username,
        presentation_name: username || user.guid,
        origin: origin,
        metadata: {
          labels: hashified_labels(user.labels),
          annotations: hashified_annotations(user.annotations),
        },
        links: build_links
      }
    end

    private

    def user
      @resource
    end

    def build_links
      {
        self: {
          href: url_builder.build_url(path: "/v3/users/#{CGI.escape(user.guid)}")
        }
      }
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
