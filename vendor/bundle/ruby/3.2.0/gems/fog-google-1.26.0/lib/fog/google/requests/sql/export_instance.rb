module Fog
  module Google
    class SQL
      ##
      # Exports data from a Cloud SQL instance to a Google Cloud Storage
      # bucket as a MySQL dump or CSV file.
      #
      # @see https://cloud.google.com/sql/docs/mysql/admin-api/v1beta4/instances/export
      class Real
        def export_instance(instance_id, uri,
                            databases: [],
                            sql_export_options: {},
                            csv_export_options: {},
                            file_type: nil)
          data = {
            :kind => "sql#exportContext",
            :uri => uri,
            :databases => databases
          }

          unless file_type.nil?
            data[:file_type] = file_type
          end

          unless csv_export_options.empty?
            data[:csv_export_options] =
              ::Google::Apis::SqladminV1beta4::ExportContext::CsvExportOptions.new(**csv_export_options)
          end

          unless sql_export_options.nil?
            data[:sql_export_options] =
              ::Google::Apis::SqladminV1beta4::ExportContext::SqlExportOptions.new(**sql_export_options)
          end

          export_context = ::Google::Apis::SqladminV1beta4::ExportContext.new(export_context)
          @sql.export_instance(
            @project,
            instance_id,
            ::Google::Apis::SqladminV1beta4::ExportInstancesRequest.new(
              export_context: export_context
            )
          )
        end
      end

      class Mock
        def export_instance(_instance_id, _uri, _options: {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
