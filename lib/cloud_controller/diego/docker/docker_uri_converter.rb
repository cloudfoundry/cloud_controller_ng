module VCAP::CloudController
  class DockerURIConverter
    DOCKER_INDEX_SERVER = 'docker.io'.freeze

    class InvalidDockerURI < StandardError; end

    def convert(docker_uri)
      raise InvalidDockerURI.new "Docker URI [#{docker_uri}] should not contain scheme" if docker_uri.include? '://'

      host, path, tag = parse_docker_repo_url(docker_uri)
      Addressable::URI.new(scheme: 'docker', host: host, path: path, fragment: tag).to_s
    end

    private

    def parse_docker_repo_url(docker_uri)
      name_parts = docker_uri.split('/', 2)

      host = name_parts[0]
      path = name_parts[1]

      if missing_registry(name_parts)
        host = ''
        path = docker_uri
      end

      if official_docker_registry(name_parts[0]) || missing_registry(name_parts)
        unless path.include?('/')
          path = 'library/' + path
        end
      end

      path, tag = parse_docker_repository_tag(path)

      [host, path, tag]
    end

    def official_docker_registry(host)
      host == DOCKER_INDEX_SERVER
    end

    def missing_registry(name_parts)
      host = name_parts[0]
      name_parts.length == 1 ||
        (!host.include?('.') && !host.include?(':') && host != 'localhost')
    end

    def parse_docker_repository_tag(path)
      path, tag = path.split(':', 2)

      unless tag && tag.include?('/')
        return [path, tag]
      end

      [path, '']
    end
  end
end
