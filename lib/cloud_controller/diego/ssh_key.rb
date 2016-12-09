require 'net/ssh'

module VCAP
  module CloudController
    module Diego
      class SSHKey
        def initialize(bits=1024)
          @bits = bits
        end

        def private_key
          key.to_pem
        end

        def authorized_key
          @auth_key ||= begin
            type = key.ssh_type
            data = [key.to_blob].pack('m0')

            "#{type} #{data}"
          end
        end

        def fingerprint
          key.fingerprint
        end

        private

        def key
          @key ||= OpenSSL::PKey::RSA.new(@bits)
        end
      end
    end
  end
end
