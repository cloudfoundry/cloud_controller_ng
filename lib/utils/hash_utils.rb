module HashUtils
  # #dig is a more-permissive alternative to Hash#dig
  #
  # HashUtils.dig(nil, 5) does not raise
  # nil.dig(5) raises
  #
  # HashUtils.dig('foo', :foo) does not raise
  # 'foo'.dig(:foo) raises
  #
  # HashUtils.dig({foo: 5}, :foo, :bar) does not raise
  # {foo: 5}.dig(:foo, :bar) raises
  def self.dig(hash, *path)
    path.inject(hash) do |location, key|
      location.is_a?(Hash) ? location[key] : nil
    end
  end
end
