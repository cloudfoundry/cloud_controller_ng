module Fog
  module Google
    class SQL
      ##
      # Deletes a SSL certificate. The change will not take effect until the instance is restarted.
      #
      # @see https://cloud.google.com/sql/docs/mysql/admin-api/v1beta4/sslCerts/delete

      class Real
        def delete_ssl_cert(instance_id, sha1_fingerprint)
          @sql.delete_ssl_cert(@project, instance_id, sha1_fingerprint)
        end
      end

      class Mock
        def delete_ssl_cert(_instance_id, _sha1_fingerprint)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
