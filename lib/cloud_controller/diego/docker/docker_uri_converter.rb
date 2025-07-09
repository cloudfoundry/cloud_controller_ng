require 'utils/uri_utils'

module VCAP::CloudController
  class DockerURIConverter
    def convert(docker_uri)
      raise UriUtils::InvalidDockerURI.new "Docker URI [#{docker_uri}] should not contain scheme" if docker_uri.include? '://'
      host, path, tag_digest = UriUtils.parse_docker_uri(docker_uri)

      # add tag or digest part as fragment to the uri, since ruby uri parser confuses with ':'
      # when it presented in path. We convert user's uri to, for example;
      # docker://docker.io/publish/ubuntu:latest -> docker://docker.io/publish/ubuntu#latest
      Addressable::URI.new(scheme: 'docker', host: host, path: path, fragment: tag_digest).to_s
    end
  end
end
