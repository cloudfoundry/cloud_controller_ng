require 'presenters/v3/pagination_presenter'

module VCAP::CloudController
  class AppPresenter
    def initialize(pagination_presenter=PaginationPresenter.new)
      @pagination_presenter = pagination_presenter
    end

    def present_json(app)
      MultiJson.dump(app_hash(app), pretty: true)
    end

    def present_json_list(paginated_result, facets={})
      apps       = paginated_result.records
      app_hashes = apps.collect { |app| app_hash(app) }

      paginated_response = {
        pagination: @pagination_presenter.present_pagination_hash(paginated_result, '/v3/apps', facets),
        resources:  app_hashes
      }

      MultiJson.dump(paginated_response, pretty: true)
    end

    private

    def app_hash(app)
      {
        guid:                    app.guid,
        name:                    app.name,
        desired_state:           app.desired_state,
        total_desired_instances: app.processes.map(&:instances).reduce(:+) || 0,
        created_at:              app.created_at,
        updated_at:              app.updated_at,
        environment_variables:   app.environment_variables || {},
        _links:                  build_links(app)
      }
    end

    def build_links(app)
      desired_droplet_link = nil
      if app.desired_droplet_guid
        desired_droplet_link = {
          href: "/v3/droplets/#{app.desired_droplet_guid}"
        }
      end

      links = {
        self:                   { href: "/v3/apps/#{app.guid}" },
        processes:              { href: "/v3/apps/#{app.guid}/processes" },
        packages:               { href: "/v3/apps/#{app.guid}/packages" },
        space:                  { href: "/v2/spaces/#{app.space_guid}" },
        desired_droplet:        desired_droplet_link,
        start:                  { href: "/v3/apps/#{app.guid}/start", method: 'PUT' },
        stop:                   { href: "/v3/apps/#{app.guid}/stop", method: 'PUT' },
        assign_current_droplet: { href: "/v3/apps/#{app.guid}/current_droplet", method: 'PUT' },
      }

      links.delete_if { |_, v| v.nil? }
    end
  end
end
