module UriUtils
  def self.is_uri?(candidate)
    !!(candidate.is_a?(String) && /\A#{URI.regexp}\Z/ =~ candidate && URI(candidate))
  rescue
    false
  end

  def self.is_uri_path?(candidate)
    !!(candidate.is_a?(String) && candidate =~ %r{^(?:/|/([^\s/][\S]*)?)$})
  end
end
