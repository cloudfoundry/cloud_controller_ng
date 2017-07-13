module UriUtils
  SSH_REGEX = %r{ \A (?:ssh://)? git@ .+? : .+? \.git \z }x
  GIT_REGEX = %r{ \A git:// .+? : .+? \.git \z }x

  def self.is_uri?(candidate)
    !!(candidate.is_a?(String) && /\A#{URI.regexp}\Z/ =~ candidate && URI(candidate))
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
end
