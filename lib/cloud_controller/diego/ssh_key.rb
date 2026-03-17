# frozen_string_literal: true

require 'openssl'
require 'digest'
require 'base64'

module VCAP
  module CloudController
    module Diego
      class SSHKey
        def initialize(bits=2048)
          @bits = bits
        end

        def private_key
          key.to_pem
        end

        def authorized_key
          @authorized_key ||= begin
            type = ssh_type
            data = [public_key_blob].pack('m0') # Base64 without newlines
            "#{type} #{data}"
          end
        end

        def fingerprint
          @fingerprint ||= colon_separated_hex(OpenSSL::Digest::SHA1.digest(public_key_blob))
        end

        def sha256_fingerprint
          @sha256_fingerprint ||= Base64.strict_encode64(OpenSSL::Digest::SHA256.digest(public_key_blob))
        end

        private

        def key
          @key ||= OpenSSL::PKey::RSA.new(@bits)
        end

        # Builds the SSH public key blob for an RSA key.
        #
        # SSH wire format for RSA public key (RFC 4253 section 6.6):
        #   string "ssh-rsa"
        #   mpint  e (public exponent)
        #   mpint  n (modulus)
        #
        # Data types defined in RFC 4251 section 5:
        # - string: uint32 length + raw bytes
        # - mpint: uint32 length + big-endian bytes (leading zero if high bit set)
        #
        # References:
        # - https://www.rfc-editor.org/rfc/rfc4251#section-5
        # - https://www.rfc-editor.org/rfc/rfc4253#section-6.6
        # - https://ruby-doc.org/3.3.0/packed_data_rdoc.html
        def public_key_blob
          @public_key_blob ||=
            ssh_string(ssh_type) +
            ssh_mpint(key.e) +
            ssh_mpint(key.n)
        end

        # Encodes a string in SSH wire format: 4-byte length prefix + raw bytes
        def ssh_string(string)
          uint32_big_endian(string.bytesize) + string
        end

        # Encodes a bignum as an SSH "mpint" (multiple precision integer).
        # Format: 4-byte length prefix + big-endian bytes.
        # If high bit is set, prepends a zero byte to indicate positive number.
        def ssh_mpint(bignum)
          return uint32_big_endian(0) if bignum.zero?

          bytes = bignum.to_s(2) # big-endian binary representation (OpenSSL::BN)

          if high_bit_set?(bytes)
            uint32_big_endian(bytes.bytesize + 1) + zero_byte + bytes
          else
            uint32_big_endian(bytes.bytesize) + bytes
          end
        end

        def uint32_big_endian(number)
          [number].pack('N') # 4-byte unsigned integer, big-endian (network byte order)
        end

        def zero_byte
          [0].pack('C') # 8-bit unsigned integer
        end

        def high_bit_set?(bytes)
          bytes.getbyte(0).anybits?(0x80) # binary: 10000000 - used to check if high bit is set
        end

        def ssh_type
          case key
          when OpenSSL::PKey::RSA then 'ssh-rsa'
          else
            raise NotImplementedError.new("Unsupported key type: #{key.class}")
          end
        end

        def colon_separated_hex(bytes)
          bytes.unpack('C*').map { |byte| sprintf('%02x', byte) }.join(':')
        end
      end
    end
  end
end
