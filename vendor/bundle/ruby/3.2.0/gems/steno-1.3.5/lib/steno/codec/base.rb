module Steno
  module Codec
  end
end

class Steno::Codec::Base
  # Encodes the supplied record as a string.
  #
  # @param [Hash] record
  #
  # @return [String]
  def encode_record(record)
    raise NotImplementedError
  end

  private

  # Hex encodes non-printable ascii characters.
  #
  # @param [String] data
  #
  # @return [String]
  def escape_nonprintable_ascii(data)
    data.chars.map do |c|
      ord_val = c.ord

      if (ord_val > 31) && (ord_val < 127)
        c
      else
        format('\\x%02x', ord_val)
      end
    end.join
  end
end
