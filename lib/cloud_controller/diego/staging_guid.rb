module VCAP::CloudController
  module Diego
    class StagingGuid
      def self.from(process_guid, process_staging_task_id)
        "#{process_guid}-#{process_staging_task_id}"
      end

      def self.from_process(process)
        return nil unless process.staging_task_id

        from(process.guid, process.staging_task_id)
      end

      def self.process_guid(staging_guid)
        staging_guid[0..35]
      end

      def self.staging_task_id(staging_guid)
        staging_guid[37..-1]
      end
    end
  end
end
