module OPI
  def self.recursive_ostruct(hash)
    OpenStruct.new(hash.map { |key, value|
                     new_val = value.is_a?(Hash) ? recursive_ostruct(value) : value
                     [key, new_val]
                   }.to_h)
  end
end
