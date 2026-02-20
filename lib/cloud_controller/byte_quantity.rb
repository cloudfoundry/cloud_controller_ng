# Derived from the palm_civet library
# Copyright (c) 2013 Anand Gaitonde
# Licensed under the MIT License
# https://github.com/goodmustache/palm_civet

module VCAP
  module CloudController
    module ByteQuantity
      BYTE     = 1.0
      KILOBYTE = 1024 * BYTE
      MEGABYTE = 1024 * KILOBYTE
      GIGABYTE = 1024 * MEGABYTE
      TERABYTE = 1024 * GIGABYTE
      BYTESPATTERN = /^(-?\d+(?:\.\d+)?)([KMGT]i?B?|B)$/i

      class InvalidByteQuantityError < RuntimeError
        def initialize(msg='byte quantity must be a positive integer with a unit of measurement like M, MB, MiB, G, GiB, or GB')
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
        raise TypeError.new('must be an integer or float') unless bytes.is_a? Numeric

        case
        when bytes >= TERABYTE
          unit = 'T'
          value = bytes / TERABYTE
        when bytes >= GIGABYTE
          unit = 'G'
          value = bytes / GIGABYTE
        when bytes >= MEGABYTE
          unit = 'M'
          value = bytes / MEGABYTE
        when bytes >= KILOBYTE
          unit = 'K'
          value = bytes / KILOBYTE
        when bytes >= BYTE
          unit = 'B'
          value = bytes
        else
          return '0'
        end

        value = sprintf('%g', sprintf('%.1f', value))
        value << unit
      end

      # Parses a string formatted by bytes_size as bytes. Note binary-prefixed and
      # SI prefixed units both mean a base-2 units:
      # * KB = K = KiB	= 1024
      # * MB = M = MiB = 1024 * K
      # * GB = G = GiB = 1024 * M
      # * TB = T = TiB = 1024 * G
      def self.to_bytes(bytes)
        matches = BYTESPATTERN.match(bytes.strip)
        raise InvalidByteQuantityError if matches.nil?

        value = Float(matches[1])

        case matches[2][0].capitalize
        when 'T'
          value *= TERABYTE
        when 'G'
          value *= GIGABYTE
        when 'M'
          value *= MEGABYTE
        when 'K'
          value *= KILOBYTE
        end

        value.to_i
      rescue TypeError
        raise InvalidByteQuantityError
      end

      # Parses a string formatted by byte_size as megabytes.
      def self.to_megabytes(bytes)
        (to_bytes(bytes) / MEGABYTE).to_i
      end
    end
  end
end
