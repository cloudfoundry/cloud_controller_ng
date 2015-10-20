module VCAP::CloudController
  class DropletPresenter
    def initialize(pagination_presenter=PaginationPresenter.new)
      @pagination_presenter = pagination_presenter
    end

    def present_json(droplet)
      MultiJson.dump(droplet_hash(droplet), pretty: true)
    end

    def present_json_list(paginated_result, base_url, params)
      droplets       = paginated_result.records
      droplet_hashes = droplets.collect { |droplet| droplet_hash(droplet) }

      paginated_response = {
        pagination: @pagination_presenter.present_pagination_hash(paginated_result, base_url, params),
        resources:  droplet_hashes
      }

      MultiJson.dump(paginated_response, pretty: true)
    end

    private

    DEFAULT_HASHING_ALGORITHM = 'sha1'

    def droplet_hash(droplet)
      {
        guid:                    droplet.guid,
        state:                   droplet.state,
        error:                   droplet.error,
        lifecycle: {
          type: droplet.lifecycle_type,
          data: droplet.lifecycle_data.to_hash
        },
        memory_limit:            droplet.memory_limit,
        disk_limit:              droplet.disk_limit,
        result: {
          buildpack:             droplet.buildpack,
          stack:                 droplet.stack_name,
          process_types:         droplet.process_types,
          hash: {
            type: DEFAULT_HASHING_ALGORITHM,
            value: droplet.droplet_hash
          },
          execution_metadata:   droplet.execution_metadata
        },
        environment_variables:  droplet.environment_variables || {},
        created_at:             droplet.created_at,
        updated_at:             droplet.updated_at,
        links:                  build_links(droplet),
      }
    end

    def build_links(droplet)
      buildpack_link = nil
      if droplet.buildpack_guid
        buildpack_link = {
          href: "/v2/buildpacks/#{droplet.buildpack_guid}"
        }
      end

      links = {
        self:                   { href: "/v3/droplets/#{droplet.guid}" },
        package:                { href: "/v3/packages/#{droplet.package_guid}" },
        app:                    { href: "/v3/apps/#{droplet.app_guid}" },
        assign_current_droplet: { href: "/v3/apps/#{droplet.app_guid}/current_droplet", method: 'PUT' },
        buildpack:              buildpack_link
      }

      links.delete_if { |_, v| v.nil? }
    end
  end
end
