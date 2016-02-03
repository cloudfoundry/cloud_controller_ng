module HashUtils
  def self.dig(hash, *path)
    path.inject(hash) do |location, key|
      location.is_a?(Hash) ? location[key] : nil
    end
  end
end
