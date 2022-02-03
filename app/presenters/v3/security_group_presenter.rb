require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class SecurityGroupPresenter < BasePresenter
    def initialize(
      resource,
      show_secrets: false,
      censored_message: VCAP::CloudController::Presenters::Censorship::REDACTED_CREDENTIAL,
      all_spaces_visible: false,
      visible_space_guids: []
    )
      super(resource, show_secrets: show_secrets, censored_message: censored_message)
      @visible_space_guids = visible_space_guids
      @all_spaces_visible = all_spaces_visible
    end

    def to_hash
      {
        guid: security_group.guid,
        created_at: security_group.created_at,
        updated_at: security_group.updated_at,
        name: security_group.name,
        rules: security_group.rules,
        globally_enabled: {
          running: security_group.running_default,
          staging: security_group.staging_default,
        },
        relationships: {
          running_spaces: {
            data: space_guid_hash_for(security_group.spaces)
          },
          staging_spaces: {
            data: space_guid_hash_for(security_group.staging_spaces)
          }
        },
        links: build_links,
      }
    end

    private

    def security_group
      @resource
    end

    def space_guid_hash_for(spaces)
      visible_spaces = if @all_spaces_visible
                         spaces
                       else
                         spaces.select { |space| @visible_space_guids.include? space.guid }
                       end
      visible_spaces.map { |space| { guid: space.guid } }
    end

    def build_links
      {
        self: { href: url_builder.build_url(path: "/v3/security_groups/#{security_group.guid}") },
      }
    end
  end
end
