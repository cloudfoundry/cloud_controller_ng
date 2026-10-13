module VCAP::CloudController
  module Diego
    class BuildpackEntryGenerator
      def initialize(blobstore_url_generator, type)
        @blobstore_url_generator = blobstore_url_generator
        @type = type
      end

      def buildpack_entries(buildpack_infos, stack_name, credentials: nil)
        return default_admin_buildpacks(stack_name) if buildpack_infos.empty?

        buildpack_infos.map do |buildpack_info|
          if buildpack_info.buildpack_exists_in_db? && buildpack_info.buildpack_enabled?
            admin_buildpack_entry(buildpack_info.buildpack_record).merge(skip_detect: true)
          elsif buildpack_info.buildpack_url
            url = inject_credentials(buildpack_info.buildpack_url, credentials)
            { name: 'custom', key: url, url: url, skip_detect: true }
          else
            raise "Unsupported buildpack type: '#{buildpack_info.buildpack}'"
          end
        end
      end

      private

      def inject_credentials(url, credentials)
        return url if credentials.blank?

        host = URI.parse(url).host
        cred = credentials[host]
        return url if cred.blank?

        username = cred['username']
        password = cred['password']
        return url if username.blank?

        uri = URI.parse(url)
        uri.user = URI.encode_www_form_component(username)
        uri.password = URI.encode_www_form_component(password) if password.present?
        uri.to_s
      rescue URI::InvalidURIError
        url
      end

      def custom_buildpack_entry(buildpack)
        { name: 'custom', key: buildpack.url, url: buildpack.url }
      end

      def default_admin_buildpacks(stack_name)
        VCAP::CloudController::Buildpack.list_admin_buildpacks(stack_name, @type).
          select(&:enabled).
          collect { |buildpack| admin_buildpack_entry(buildpack) }
      end

      def admin_buildpack_entry(buildpack)
        {
          name: buildpack.name,
          key: buildpack.key,
          sha256: buildpack.sha256_checksum,
          url: @blobstore_url_generator.admin_buildpack_download_url(buildpack),
          skip_detect: false
        }
      end
    end
  end
end
