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

    DEFAULT_HASHING_ALGORITHM = 'sha1'.freeze

    def droplet_hash(droplet)
      {
        guid:                  droplet.guid,
        state:                 droplet.state,
        error:                 droplet.error,
        lifecycle:             {
          type: droplet.lifecycle_type,
          data: droplet.lifecycle_data.as_json
        },
        memory_limit:          droplet.memory_limit,
        disk_limit:            droplet.disk_limit,
        result:                result_for_lifecycle(droplet),
        environment_variables: droplet.environment_variables || {},
        created_at:            droplet.created_at,
        updated_at:            droplet.updated_at,
        links:                 build_links(droplet),
      }
    end

    def build_links(droplet)
      {
        self:                   { href: "/v3/droplets/#{droplet.guid}" },
        package:                { href: "/v3/packages/#{droplet.package_guid}" },
        app:                    { href: "/v3/apps/#{droplet.app_guid}" },
        assign_current_droplet: { href: "/v3/apps/#{droplet.app_guid}/current_droplet", method: 'PUT' },
      }.merge(links_for_lifecyle(droplet))
    end

    def result_for_lifecycle(droplet)
      return nil unless DropletModel::COMPLETED_STATES.include?(droplet.state)

      lifecycle_result = if droplet.lifecycle_type == Lifecycles::BUILDPACK
                           {
                             hash:
                             {
                               type:  DEFAULT_HASHING_ALGORITHM,
                               value: droplet.droplet_hash,
                             },
                             buildpack: droplet.buildpack_receipt_buildpack,
                             stack:     droplet.buildpack_receipt_stack_name,
                           }
                         elsif droplet.lifecycle_type == Lifecycles::DOCKER
                           {
                             image: droplet.docker_receipt_image
                           }
                         end

      {
        execution_metadata: droplet.execution_metadata,
        process_types:      droplet.process_types
      }.merge(lifecycle_result)
    end

    def links_for_lifecyle(droplet)
      links = {}

      if droplet.lifecycle_type == Lifecycles::BUILDPACK
        if droplet.buildpack_receipt_buildpack_guid
          links[:buildpack] = { href: "/v2/buildpacks/#{droplet.buildpack_receipt_buildpack_guid}" }
        end
      end

      links
    end
  end
end
