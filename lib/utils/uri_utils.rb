module UriUtils
  SSH_REGEX = %r{ \A (?:ssh://)? git@ .+? : .+? \.git \z }x.freeze
  GIT_REGEX = %r{ \A git:// .+? : .+? \.git \z }x.freeze

  def self.is_uri?(candidate)
    !!(candidate.is_a?(String) && /\A#{URI::DEFAULT_PARSER.make_regexp}\Z/ =~ candidate && URI(candidate))
  rescue
    false
  end

  def self.is_buildpack_uri?(candidate)
    return false unless candidate.is_a?(String)
    return true if is_uri?(candidate)

    !!(SSH_REGEX.match(candidate) || GIT_REGEX.match(candidate))
  end

  def self.is_uri_path?(candidate)
    !!(candidate.is_a?(String) && candidate =~ %r{^(?:/|/([^\s/][\S]*)?)$})
  end

  # This escapes only the values in queries.
  def self.uri_escape(uri)
    parts = uri.split('?', 2)
    return uri if parts.size == 1

    query = parts[1].split('&').map { |subquery|
      subparts = subquery.split('=', 2)
      if subparts.size == 1
        CGI.escape(subparts[0])
      else
        [subparts[0], CGI.escape(subparts[1])].join('=')
      end
    }.join('&')
    [parts[0].tr(' ', '+'), query].join('?')
  end
end
