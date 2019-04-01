module VCAP::CloudController
  module Diego
    class LifecycleBundleUriGenerator
      class InvalidStack < StandardError; end
      class InvalidCompiler < StandardError; end

      def self.uri(lifecycle_bundle)
        raise InvalidStack.new('no compiler defined for requested stack') unless lifecycle_bundle

        lifecycle_bundle_url = URI(lifecycle_bundle)

        case lifecycle_bundle_url.scheme
        when 'http', 'https'
          lifecycle_cached_dependency_uri = lifecycle_bundle_url
        when nil
          lifecycle_cached_dependency_uri = URI(Config.config.get(:diego, :file_server_url))
          lifecycle_cached_dependency_uri.path = "/v1/static/#{lifecycle_bundle}"
        else
          raise InvalidCompiler.new('invalid compiler URI')
        end
        lifecycle_cached_dependency_uri.to_s
      end
    end
  end
end
