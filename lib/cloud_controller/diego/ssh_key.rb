require 'net/ssh'
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
            type = ssh_type_for(key)
            data = [public_key_blob].pack('m0') # Base64 without newlines
            "#{type} #{data}"
          end
        end

        def fingerprint
          @fingerprint ||= colon_hex(OpenSSL::Digest::SHA1.digest(public_key_blob)) # 3)
        end

        def sha256_fingerprint
          @sha256_fingerprint ||= Base64.strict_encode64(OpenSSL::Digest::SHA256.digest(public_key_blob))
        end

        private

        def key
          @key ||= OpenSSL::PKey::RSA.new(@bits)
        end

        def public_key_blob
          @public_key_blob ||= begin
            b = Net::SSH::Buffer.new
            b.write_string(ssh_type_for(key)) # key type
            b.write_bignum(key.e)             # public exponent (e)
            b.write_bignum(key.n)             # modulus (n)
            b.to_s
          end
        end

        def ssh_type_for(key)
          case key
          when OpenSSL::PKey::RSA then 'ssh-rsa' # net-ssh doesn’t publish a constant for this
          else
            raise NotImplementedError.new("Unsupported key type: #{key.class}")
          end
        end

        def colon_hex(bytes)
          bytes.unpack('C*').map { |b| sprintf('%02x', b) }.join(':') # byte-wise hex with colons
        end
      end
    end
  end
end
