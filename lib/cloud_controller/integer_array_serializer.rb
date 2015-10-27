module VCAP::CloudController::IntegerArraySerializer
  def self.extended(other)
    Sequel::Plugins::Serialization.register_format(:integer_array, serializer, deserializer)
  end

  def self.serializer
    lambda do |array|
      return if array.nil?
      raise ArgumentError.new('Integer array columns must be passed an array') unless array.is_a?(Array)
      raise ArgumentError.new('All members of the array must be integers') unless array.all? { |v| v.is_a? Integer }

      array
    end
  end

  def self.deserializer
    lambda do |raw_string|
      if raw_string.nil?
        raw_string
      elsif raw_string.include?(',')
        raw_string[1..-2].split(',').map(&:to_i)
      else
        [Integer(raw_string)]
      end
    end
  end
end
