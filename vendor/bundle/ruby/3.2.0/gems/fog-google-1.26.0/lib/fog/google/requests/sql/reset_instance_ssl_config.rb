module Fog
  module Google
    class SQL
      ##
      # Deletes all client certificates and generates a new server SSL certificate for the instance.
      # The changes will not take effect until the instance is restarted. Existing instances without
      # a server certificate will need to call this once to set a server certificate
      #
      # @see https://cloud.google.com/sql/docs/mysql/admin-api/v1beta4/instances/resetSslConfig

      class Real
        def reset_instance_ssl_config(instance_id)
          @sql.reset_instance_ssl_config(@project, instance_id)
        end
      end

      class Mock
        def reset_instance_ssl_config(_instance_id)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
