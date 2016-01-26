require 'presenters/v3/pagination_presenter'

module VCAP::CloudController
  class AppPresenter
    def initialize(pagination_presenter=PaginationPresenter.new)
      @pagination_presenter = pagination_presenter
    end

    def present_json(app)
      MultiJson.dump(app_hash(app), pretty: true)
    end

    def present_json_env(app)
      MultiJson.dump(env_hash(app), pretty: true)
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
        lifecycle: {
          type: app.lifecycle_type,
          data: app.lifecycle_data.to_hash
        },
        environment_variables:   app.environment_variables || {},
        links:                   build_links(app)
      }
    end

    def env_hash(app)
      vcap_application = {
        'VCAP_APPLICATION' => {
          limits: {
            fds: Config.config[:instance_file_descriptor_limit] || 16384,
          },
          application_name: app.name,
          application_uris: app.routes.map(&:fqdn),
          name: app.name,
          space_name: app.space.name,
          space_id: app.space.guid,
          uris: app.routes.map(&:fqdn),
          users: nil
        }
      }

      {
        'environment_variables' => app.environment_variables,
        'staging_env_json' => EnvironmentVariableGroup.staging.environment_json,
        'running_env_json' => EnvironmentVariableGroup.running.environment_json,
        'application_env_json' => vcap_application
      }
    end

    def build_links(app)
      droplet_link = nil
      if app.droplet_guid
        droplet_link = {
          href: "/v3/droplets/#{app.droplet_guid}"
        }
      end

      links = {
        self:                   { href: "/v3/apps/#{app.guid}" },
        space:                  { href: "/v2/spaces/#{app.space_guid}" },
        processes:              { href: "/v3/apps/#{app.guid}/processes" },
        routes:                 { href: "/v3/apps/#{app.guid}/routes" },
        packages:               { href: "/v3/apps/#{app.guid}/packages" },
        droplet:                droplet_link,
        droplets:               { href: "/v3/apps/#{app.guid}/droplets" },
        start:                  { href: "/v3/apps/#{app.guid}/start", method: 'PUT' },
        stop:                   { href: "/v3/apps/#{app.guid}/stop", method: 'PUT' },
        assign_current_droplet: { href: "/v3/apps/#{app.guid}/current_droplet", method: 'PUT' },
      }

      links.delete_if { |_, v| v.nil? }
    end
  end
end
