module VCAP::CloudController
  module Diego
    class StagingRequest
      attr_accessor :app_id, :file_descriptors, :memory_mb, :disk_mb, :environment
      attr_accessor :egress_rules, :timeout, :log_guid, :lifecycle, :lifecycle_data

      def message
        message = {
          app_id: app_id,
          file_descriptors: file_descriptors,
          memory_mb: memory_mb,
          disk_mb: disk_mb,
          environment: environment,
          timeout: timeout,
          log_guid: log_guid,
          lifecycle: lifecycle,
        }
        message[:lifecycle_data] = lifecycle_data if lifecycle_data
        message[:egress_rules] = egress_rules if egress_rules

        schema.validate(message)
        message
      end

      private

      def schema
        @schema ||= Membrane::SchemaParser.parse do
          {
            app_id: String,
            file_descriptors: Fixnum,
            memory_mb: Fixnum,
            disk_mb: Fixnum,
            environment: [
              { 'name' => String, 'value' => String },
            ],
            optional(:egress_rules) => Array,
            timeout: Fixnum,
            log_guid: String,
            lifecycle: String,
            optional(:lifecycle_data) => Hash,
          }
        end
      end
    end
  end
end
