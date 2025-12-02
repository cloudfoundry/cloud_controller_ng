module Fog
  module Google
    class SQL
      ##
      # Retrieves a particular SSL certificate (does not include the private key)
      #
      # @see https://cloud.google.com/sql/docs/mysql/admin-api/v1beta4/sslCerts/get

      class Real
        def get_ssl_cert(instance_id, sha1_fingerprint)
          @sql.get_ssl_cert(@project, instance_id, sha1_fingerprint)
        end
      end

      class Mock
        def get_ssl_cert(_instance_id, _sha1_fingerprint)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
