module Fog
  module Google
    class SQL
      ##
      # Imports data into a Cloud SQL instance from a MySQL dump file in Google Cloud Storage
      #
      # @see https://cloud.google.com/sql/docs/mysql/admin-api/v1beta4/instances/import

      class Real
        def import_instance(instance_id, uri, database: nil,
                            csv_import_options: nil, file_type: nil,
                            import_user: nil)
          data = {
            :kind => "sql#importContext",
            :uri => uri
          }
          data[:database] = database unless database.nil?
          data[:file_type] = file_type unless file_type.nil?
          data[:import_user] = import_user unless import_user.nil?
          unless csv_import_options.nil?
            data[:csv_import_options] =
              ::Google::Apis::SqladminV1beta4::ImportContext::CsvImportOptions.new(**csv_import_options)
          end

          @sql.import_instance(
            @project,
            instance_id,
            ::Google::Apis::SqladminV1beta4::ImportInstancesRequest.new(
              import_context: ::Google::Apis::SqladminV1beta4::ImportContext.new(**data)
            )
          )
        end
      end

      class Mock
        def import_instance(_instance_id, _uri, _options = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
