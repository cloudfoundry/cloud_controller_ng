require 'utils/uri_utils'

module VCAP::CloudController
  class DockerURIConverter
    def convert(docker_uri)
      raise UriUtils::InvalidDockerURI.new "Docker URI [#{docker_uri}] should not contain scheme" if docker_uri.include? '://'

      host, path, tag = UriUtils.parse_docker_uri(docker_uri)
      Addressable::URI.new(scheme: 'docker', host: host, path: path, fragment: tag).to_s
    end
  end
end
