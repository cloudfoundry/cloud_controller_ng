require 'utils/uri_utils'

module VCAP::CloudController
  module Diego
    # Converts docker://host/path:tag to Diego BBS rootfs format docker://host/path#tag
    module CustomStackUriConverter
      module_function

      def convert(custom_stack_uri)
        raw = custom_stack_uri.delete_prefix('docker://')
        host, path, tag_digest = UriUtils.parse_docker_uri(raw)
        Addressable::URI.new(scheme: 'docker', host: host, path: path, fragment: tag_digest).to_s
      end
    end
  end
end
