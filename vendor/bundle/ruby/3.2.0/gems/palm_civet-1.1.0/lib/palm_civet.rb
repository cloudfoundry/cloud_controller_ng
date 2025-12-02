require "palm_civet/version"

module PalmCivet
  BYTE     = 1.0
  KILOBYTE = 1024 * BYTE
  MEGABYTE = 1024 * KILOBYTE
  GIGABYTE = 1024 * MEGABYTE
  TERABYTE = 1024 * GIGABYTE
  BYTESPATTERN = /^(-?\d+(?:\.\d+)?)([KMGT]i?B?|B)$/i

	class InvalidByteQuantityError < RuntimeError
    def initialize(msg="byte quantity must be a positive integer with a unit of measurement like M, MB, MiB, G, GiB, or GB")
      super
    end
	end

  # Returns a human-readable byte string of the form 10M, 12.5K, and so forth.
  # The following units are available:
  # * T: Terabyte
  # * G: Gigabyte
  # * M: Megabyte
  # * K: Kilobyte
  # * B: Byte
  # The unit that results in the smallest number greater than or equal to 1 is
  # always chosen.
  def self.byte_size(bytes)
    if !bytes.is_a? Numeric
      raise TypeError, "must be an integer or float"
    end

    case
    when bytes >= TERABYTE
      unit = "T"
      value = bytes / TERABYTE
    when bytes >= GIGABYTE
      unit = "G"
      value = bytes / GIGABYTE
    when bytes >= MEGABYTE
      unit = "M"
      value = bytes / MEGABYTE
    when bytes >= KILOBYTE
      unit = "K"
      value = bytes / KILOBYTE
    when bytes >= BYTE
      unit = "B"
      value = bytes
    else
      return "0"
    end

    value = "%g" % ("%.1f" % value)
    return value << unit
  end

  # Parses a string formatted by bytes_size as bytes. Note binary-prefixed and
  # SI prefixed units both mean a base-2 units:
  # * KB = K = KiB	= 1024
  # * MB = M = MiB = 1024 * K
  # * GB = G = GiB = 1024 * M
  # * TB = T = TiB = 1024 * G
  def self.to_bytes(bytes)
    matches = BYTESPATTERN.match(bytes.strip)
    if matches == nil
      raise InvalidByteQuantityError
    end

    value = Float(matches[1])

    case matches[2][0].capitalize
    when "T"
      value = value * TERABYTE
    when "G"
      value = value * GIGABYTE
    when "M"
      value = value * MEGABYTE
    when "K"
      value = value * KILOBYTE
    end

    return value.to_i
  rescue TypeError
    raise InvalidByteQuantityError
  end

  # Parses a string formatted by byte_size as megabytes.
  def self.to_megabytes(bytes)
    (self.to_bytes(bytes) / MEGABYTE).to_i
  end
end
