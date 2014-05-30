module EscapedPath
  def self.join(parts)
    Regexp.compile(parts.join('[\\\/]') + '[\\\/]')
  end
end
