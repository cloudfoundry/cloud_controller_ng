require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class DeploymentPresenter < BasePresenter
    def to_hash
      {
        guid: deployment.guid,
        state: deployment.state,
        droplet: {
          guid: deployment.droplet_guid
        },
        previous_droplet: {
          guid: deployment.previous_droplet_guid
        },
        created_at: deployment.created_at,
        updated_at: deployment.updated_at,
        relationships: {
          app: {
            data: {
              guid: deployment.app.guid
            }
          }
        },
        links: build_links,
      }
    end

    private

    def deployment
      @resource
    end

    def build_links
      url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new

      {
        self: {
          href: url_builder.build_url(path: "/v3/deployments/#{deployment.guid}")
        },
        app: {
          href: url_builder.build_url(path: "/v3/apps/#{deployment.app.guid}")
        },
      }
    end
  end
end
