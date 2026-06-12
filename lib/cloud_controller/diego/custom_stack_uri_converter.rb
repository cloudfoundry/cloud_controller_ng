require 'utils/uri_utils'

module VCAP::CloudController
  module Diego
    class CustomStackUriConverter
      # Converts a custom stack URI from the user-facing format (docker://host/path:tag)
      # to the Diego BBS rootfs format (docker://host/path#tag).
      # This reuses the same conversion logic that Docker lifecycle uses.
      def convert(custom_stack_uri)
        # Strip the docker:// scheme prefix to get the raw image reference
        raw_image_ref = custom_stack_uri.sub(%r{\Adocker://}, '')

        host, path, tag_digest = UriUtils.parse_docker_uri(raw_image_ref)

        Addressable::URI.new(scheme: 'docker', host: host, path: path, fragment: tag_digest).to_s
      end
    end
  end
end
