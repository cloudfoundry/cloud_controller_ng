module Fog
  module Google
    class SQL
      ##
      # Creates an SSL certificate. The new certificate will not be usable until the instance is restarted.
      #
      # @see https://cloud.google.com/sql/docs/mysql/admin-api/v1beta4/sslCerts/insert

      class Real
        def insert_ssl_cert(instance_id, common_name)
          @sql.insert_ssl_cert(
            @project,
            instance_id,
            ::Google::Apis::SqladminV1beta4::InsertSslCertsRequest.new(
              common_name: common_name
            )
          )
        end
      end

      class Mock
        def insert_ssl_cert(_instance_id, _common_name)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
