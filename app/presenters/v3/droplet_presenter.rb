module VCAP::CloudController
  class DropletPresenter
    def initialize(pagination_presenter=PaginationPresenter.new)
      @pagination_presenter = pagination_presenter
    end

    def present_json(droplet)
      MultiJson.dump(droplet_hash(droplet), pretty: true)
    end

    def present_json_list(paginated_result, base_url)
      droplets       = paginated_result.records
      droplet_hashes = droplets.collect { |droplet| droplet_hash(droplet) }

      paginated_response = {
        pagination: @pagination_presenter.present_pagination_hash(paginated_result, base_url),
        resources:  droplet_hashes
      }

      MultiJson.dump(paginated_response, pretty: true)
    end

    private

    def droplet_hash(droplet)
      {
        guid:                   droplet.guid,
        state:                  droplet.state,
        hash:                   droplet.droplet_hash,
        buildpack_git_url:      droplet.buildpack_git_url,
        failure_reason:         droplet.failure_reason,
        detected_start_command: droplet.detected_start_command,
        procfile:               droplet.procfile,
        environment_variables:  droplet.environment_variables || {},
        created_at:             droplet.created_at,
        updated_at:             droplet.updated_at,
        _links:                 build_links(droplet),
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
        self: { href: "/v3/droplets/#{droplet.guid}" },
        package: { href: "/v3/packages/#{droplet.package_guid}" },
        app: { href: "/v3/apps/#{droplet.app_guid}" },
        buildpack: buildpack_link
      }

      links.delete_if { |_, v| v.nil? }
    end
  end
end
