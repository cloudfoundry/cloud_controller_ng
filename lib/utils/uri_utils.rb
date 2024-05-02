require 'uri'

module UriUtils
  SSH_REGEX = %r{ \A (?:ssh://)? git@ .+? : .+? \.git \z }x
  GIT_REGEX = %r{ \A git:// .+? : .+? \.git \z }x
  DOCKER_INDEX_SERVER = 'docker.io'.freeze

  class InvalidDockerURI < StandardError; end

  def self.is_uri?(candidate)
    !!(candidate.is_a?(String) && /\A#{URI::DEFAULT_PARSER.make_regexp}\Z/ =~ candidate && URI(candidate))
  rescue StandardError
    false
  end

  def self.is_buildpack_uri?(candidate)
    return false unless candidate.is_a?(String)
    return true if is_uri?(candidate)

    !!(SSH_REGEX.match(candidate) || GIT_REGEX.match(candidate))
  end

  def self.is_cnb_buildpack_uri?(candidate)
    return false unless candidate.is_a?(String)
    return is_uri?(candidate) if candidate.start_with?(%r{\Ahttp(s)?://}x)
    return !!parse_docker_uri(candidate.split('://').last) if candidate.start_with?('docker://')

    false
  rescue StandardError
    false
  end

  def self.is_uri_path?(candidate)
    !!(candidate.is_a?(String) && candidate =~ %r{^(?:/|/([^\s/][\S]*)?)$})
  end

  # This escapes only the values in queries.
  def self.uri_escape(uri)
    parts = uri.split('?', 2)
    return uri if parts.size == 1

    query = parts[1].split('&').map do |subquery|
      subparts = subquery.split('=', 2)
      if subparts.size == 1
        CGI.escape(subparts[0])
      else
        [subparts[0], CGI.escape(subparts[1])].join('=')
      end
    end.join('&')
    [parts[0].tr(' ', '+'), query].join('?')
  end

  def self.parse_docker_uri(docker_uri)
    name_parts = docker_uri.split('/', 2)

    host = name_parts[0]
    path = name_parts[1]

    if missing_registry(name_parts)
      host = ''
      path = docker_uri
    end

    path = 'library/' + path if (official_docker_registry(name_parts[0]) || missing_registry(name_parts)) && path.exclude?('/')

    path, tag = parse_docker_repository_tag(path)

    raise InvalidDockerURI.new "Invalid image name [#{path}]" unless %r{\A[a-z0-9_\-\.\/]{2,255}\Z} =~ path
    raise InvalidDockerURI.new "Invalid image tag [#{tag}]" if tag && !(/\A[a-zA-Z0-9_\-\.]{1,128}(@sha256:[a-z0-9]{64})?\Z/ =~ tag)

    [host, path, tag]
  end

  private_class_method def self.official_docker_registry(host)
    host == DOCKER_INDEX_SERVER
  end

  private_class_method def self.missing_registry(name_parts)
    host = name_parts[0]
    name_parts.length == 1 ||
    (host.exclude?('.') && host.exclude?(':') && host != 'localhost')
  end

  private_class_method def self.parse_docker_repository_tag(path)
    path, tag = path.split(':', 2)

    return [path, tag] unless tag && tag.include?('/')

    [path, 'latest']
  end
end
