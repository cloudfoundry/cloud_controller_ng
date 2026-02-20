require 'cloud_controller/byte_quantity'

module VCAP::CloudController
  class ByteConverter
    class InvalidBytesError < StandardError; end
    class InvalidUnitsError < StandardError; end
    class NonNumericError < StandardError; end

    def convert_to_mb(human_readable_byte_value)
      return nil if human_readable_byte_value.blank?
      raise NonNumericError unless human_readable_byte_value.to_s.match?(/\A-?\d+(?:\.\d+)?/)

      ByteQuantity.to_megabytes(human_readable_byte_value.to_s)
    rescue ByteQuantity::InvalidByteQuantityError
      raise InvalidUnitsError
    end

    def convert_to_b(human_readable_byte_value)
      return nil if human_readable_byte_value.blank?
      raise NonNumericError unless human_readable_byte_value.to_s.match?(/\A-?\d+(?:\.\d+)?/)

      ByteQuantity.to_bytes(human_readable_byte_value.to_s)
    rescue ByteQuantity::InvalidByteQuantityError
      raise InvalidUnitsError
    end

    def human_readable_byte_value(bytes)
      return nil if bytes.blank?

      raise InvalidBytesError unless bytes.is_a?(Integer)

      units = %w[B K M G T]
      while units.any?
        unit_in_bytes = 1024**(units.length - 1)
        return "#{bytes / unit_in_bytes}#{units.last}" if bytes.remainder(unit_in_bytes).zero?

        units.pop
      end
    end
  end
end
