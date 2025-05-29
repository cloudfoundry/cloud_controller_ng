require 'net/ssh'
require 'sshkey'

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
            type = key.ssh_type
            data = [key.to_blob].pack('m0')

            "#{type} #{data}"
          end
        end

        def fingerprint
          @fingerprint ||= ::SSHKey.new(key.to_der).sha1_fingerprint
        end

        def sha256_fingerprint
          @sha256_fingerprint ||= ::SSHKey.new(key.to_der).sha256_fingerprint
        end

        private

        def key
          @key ||= OpenSSL::PKey::RSA.new(@bits)
        end
      end
    end
  end
end
