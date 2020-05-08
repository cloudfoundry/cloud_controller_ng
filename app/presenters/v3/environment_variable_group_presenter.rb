require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class EnvironmentVariableGroupPresenter < BasePresenter
    def to_hash
      {
        updated_at: env_group.updated_at,
        name: env_group.name,
        var: env_group.environment_json,
        links: build_links
      }
    end

    private

    def env_group
      @resource
    end

    def build_links
      {
        self: {
          href: url_builder.build_url(path: "/v3/environment_variable_groups/#{env_group.name}")
        },
      }
    end
  end
end
