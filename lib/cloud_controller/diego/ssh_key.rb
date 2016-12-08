require 'net/ssh'

module VCAP
  module CloudController
    module Diego
      class SSHKey
        def initialize(bits=1024)
          @key = OpenSSL::PKey::RSA.new(bits)
        end

        def private_key
          @key.to_pem
        end

        def authorized_key
          @auth_key ||= begin
            type = @key.ssh_type
            data = [@key.to_blob].pack('m0')

            "#{type} #{data}"
          end
        end

        def fingerprint
          @key.fingerprint
        end
      end
    end
  end
end
