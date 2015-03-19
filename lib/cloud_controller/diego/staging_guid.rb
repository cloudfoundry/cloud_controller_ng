module VCAP::CloudController
  module Diego
    class StagingGuid
      def self.from(app_guid, app_staging_task_id)
        "#{app_guid}-#{app_staging_task_id}"
      end

      def self.from_app(app)
        return nil unless app.staging_task_id

        from(app.guid, app.staging_task_id)
      end

      def self.app_guid(staging_guid)
        staging_guid[0..35]
      end

      def self.staging_task_id(staging_guid)
        staging_guid[37..-1]
      end
    end
  end
end
