module VCAP::CloudController::IntegerArraySerializer
  def self.extended(other)
    Sequel::Plugins::Serialization.register_format(:integer_array, serializer, deserializer)
  end

  def self.serializer
    lambda do |array|
      return nil if array.nil? || array.empty?
      raise ArgumentError.new('Integer array columns must be passed an array') unless array.is_a?(Array)
      raise ArgumentError.new('All members of the array must be integers') unless array.all? { |v| v.is_a? Integer }

      array.join(',')
    end
  end

  def self.deserializer
    lambda do |raw_string|
      if raw_string.nil?
        raw_string
      else
        raw_string.split(',').map(&:to_i)
      end
    end
  end
end
