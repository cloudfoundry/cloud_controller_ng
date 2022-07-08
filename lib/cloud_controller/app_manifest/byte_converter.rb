require 'palm_civet'

module VCAP::CloudController
  class ByteConverter
    class InvalidBytesError < StandardError; end
    class InvalidUnitsError < StandardError; end
    class NonNumericError < StandardError; end

    def convert_to_mb(human_readable_byte_value)
      return nil unless human_readable_byte_value.present?
      if !human_readable_byte_value.to_s.match?(/\A-?\d+(?:\.\d+)?/)
        raise NonNumericError
      end

      PalmCivet.to_megabytes(human_readable_byte_value.to_s)
    rescue PalmCivet::InvalidByteQuantityError
      raise InvalidUnitsError
    end

    def convert_to_b(human_readable_byte_value)
      return nil unless human_readable_byte_value.present?
      if !human_readable_byte_value.to_s.match?(/\A-?\d+(?:\.\d+)?/)
        raise NonNumericError
      end

      PalmCivet.to_bytes(human_readable_byte_value.to_s)
    rescue PalmCivet::InvalidByteQuantityError
      raise InvalidUnitsError
    end

    def human_readable_byte_value(bytes)
      return nil unless bytes.present?

      if !bytes.is_a?(Integer)
        raise InvalidBytesError
      end

      units = %w(B K M G T)
      while units.any?
        unit_in_bytes = 1024**(units.length - 1)
        if bytes.remainder(unit_in_bytes).zero?
          return "#{bytes / unit_in_bytes}#{units.last}"
        end

        units.pop
      end
    end
  end
end
