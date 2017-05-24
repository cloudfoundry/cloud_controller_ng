module VCAP::CloudController
  module Diego
    class StagingRequest
      attr_accessor :app_id, :file_descriptors, :memory_mb, :disk_mb, :environment, :isolation_segment
      attr_accessor :egress_rules, :timeout, :log_guid, :lifecycle, :lifecycle_data, :completion_callback

      def message
        message = {
          app_id:              app_id,
          file_descriptors:    file_descriptors,
          memory_mb:           memory_mb,
          disk_mb:             disk_mb,
          environment:         environment,
          timeout:             timeout,
          log_guid:            log_guid,
          lifecycle:           lifecycle,
          completion_callback: completion_callback
        }
        message[:lifecycle_data] = lifecycle_data if lifecycle_data
        message[:egress_rules]   = egress_rules if egress_rules
        message[:isolation_segment] = isolation_segment if isolation_segment

        schema.validate(message)
        message
      end

      private

      def schema
        @schema ||= Membrane::SchemaParser.parse do
          {
            app_id:                   String,
            file_descriptors:         Integer,
            memory_mb:                Integer,
            disk_mb:                  Integer,
            environment:              [
              { 'name' => String, 'value' => String },
            ],
            optional(:egress_rules) => Array,
            timeout:                  Integer,
            log_guid:                 String,
            lifecycle:                String,
            optional(:lifecycle_data) => Hash,
            completion_callback:      String,
            optional(:isolation_segment) => String,
          }
        end
      end
    end
  end
end
