module Fog
  module Google
    class SQL
      ##
      # Creates a Cloud SQL instance as a clone of the source instance
      #
      # @see https://cloud.google.com/sql/docs/mysql/admin-api/v1beta4/instances/clone
      class Real
        def clone_instance(instance_id, destination_name,
                           log_filename: nil, log_position: nil)
          context = {
            :kind => "sql#cloneContext",
            :destination_instance_name => destination_name
          }

          unless log_filename.nil? || log_position.nil?
            context[:bin_log_coordinates] = ::Google::Apis::SqladminV1beta4::BinLogCoordinates.new(
              kind: "sql#binLogCoordinates",
              log_filename: log_filename,
              log_position: log_position
            )
          end

          clone_request = ::Google::Apis::SqladminV1beta4::CloneInstancesRequest.new(
            clone_context: ::Google::Apis::SqladminV1beta4::CloneContext.new(**context)
          )

          @sql.clone_instance(@project, instance_id, clone_request)
        end
      end

      class Mock
        def clone_instance(_instance_id, _destination_name,
                           _log_filename: nil, _log_position: nil)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
