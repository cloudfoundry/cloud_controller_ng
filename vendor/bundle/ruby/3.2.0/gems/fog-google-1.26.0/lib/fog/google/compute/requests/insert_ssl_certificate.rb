module Fog
  module Google
    class Compute
      class Mock
        def insert_ssl_certificate(_certificate_name, _certificate, _private_key, _options = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def insert_ssl_certificate(certificate_name, certificate, private_key, description: nil)
          @compute.insert_ssl_certificate(
            @project,
            ::Google::Apis::ComputeV1::SslCertificate.new(
              certificate: certificate,
              name: certificate_name,
              private_key: private_key,
              description: description
            )
          )
        end
      end
    end
  end
end
