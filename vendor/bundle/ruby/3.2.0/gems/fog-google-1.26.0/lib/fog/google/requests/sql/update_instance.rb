module Fog
  module Google
    class SQL
      ##
      # Updates settings of a Cloud SQL instance
      #
      # @see https://cloud.google.com/sql/docs/mysql/admin-api/v1beta4/instances/update
      class Real
        def update_instance(instance_id, settings_version, tier, settings = {})
          settings = ::Google::Apis::SqladminV1beta4::Settings.new(**settings)
          settings.tier = tier
          settings.settings_version = settings_version

          @sql.update_instance(
            @project,
            instance_id,
            ::Google::Apis::SqladminV1beta4::DatabaseInstance.new(settings: settings)
          )
        end
      end

      class Mock
        def update_instance(_instance_id, _settings_version, _tier, _settings = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
