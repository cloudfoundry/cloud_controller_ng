module VCAP::CloudController
  class PackagePresenter
    def initialize(pagination_presenter=PaginationPresenter.new)
      @pagination_presenter = pagination_presenter
    end

    def present_json(package)
      package_hash = package_hash(package)

      MultiJson.dump(package_hash, pretty: true)
    end

    def present_json_list(paginated_result, base_url)
      packages       = paginated_result.records
      package_hashes = packages.collect { |package| package_hash(package) }

      paginated_response = {
        pagination: @pagination_presenter.present_pagination_hash(paginated_result, base_url),
        resources:  package_hashes
      }

      MultiJson.dump(paginated_response, pretty: true)
    end

    private

    DEFAULT_HASHING_ALGORITHM = 'sha1'

    def package_hash(package)
      {
        guid:       package.guid,
        type:       package.type,
        data:       build_data(package),
        state:      package.state,
        created_at: package.created_at,
        updated_at: package.updated_at,
        links:      build_links(package),
      }
    end

    def build_data(package)
      data = general_data(package)
      return data unless package.type == 'docker' && package.docker_data
      docker_data = package.docker_data
      data[:image]       = docker_data.image
      data[:credentials] = docker_data.credentials
      data[:store_image] = docker_data.store_image
      data
    end

    def general_data(package)
      {
        hash: {
          type: DEFAULT_HASHING_ALGORITHM,
          value: package.package_hash
        },
        error:      package.error,
      }
    end

    def build_links(package)
      upload_link = nil
      if package.type == 'bits'
        upload_link = { href: "/v3/packages/#{package.guid}/upload", method: 'POST' }
        download_link = { href: "/v3/packages/#{package.guid}/download", method: 'GET' }
        stage_link = { href: "/v3/packages/#{package.guid}/droplets", method: 'POST' }
      end

      links = {
        self:   {
          href: "/v3/packages/#{package.guid}"
        },
        upload: upload_link,
        download: download_link,
        stage: stage_link,
        app:  {
          href: "/v3/apps/#{package.app_guid}",
        },
      }

      links.delete_if { |_, v| v.nil? }
    end
  end
end
