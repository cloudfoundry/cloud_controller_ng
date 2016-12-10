class Object
  def is_uri?
    self.is_a?(String) && /\A#{URI.regexp}\Z/ =~ self && URI(self)
  rescue
    false
  end

  def is_uri_path?
    self.is_a?(String) && %r{\A/\S+\Z} =~ self
  end
end
