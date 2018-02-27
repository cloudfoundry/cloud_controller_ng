require 'palm_civet'

module VCAP::CloudController
  class ByteConverter
    class InvalidUnitsError < StandardError; end

    def convert_to_mb(human_readable_byte_value)
      return nil unless human_readable_byte_value.present?

      PalmCivet.to_megabytes(human_readable_byte_value.to_s)
    rescue PalmCivet::InvalidByteQuantityError
      raise InvalidUnitsError
    end
  end
end
