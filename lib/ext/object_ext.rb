class Object
  def is_uri?
    !!(self.is_a?(String) && /\A#{URI.regexp}\Z/ =~ self && URI(self))
  rescue
    false
  end

  def is_uri_path?
    !!(self.is_a?(String) && self =~ %r{^(?:/|/([^\s/][\S]*)?)$})
  end
end
