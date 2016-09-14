class Object
  def is_uri?
    self.is_a?(String) && /\A#{URI.regexp}\Z/ =~ self
  end
end
