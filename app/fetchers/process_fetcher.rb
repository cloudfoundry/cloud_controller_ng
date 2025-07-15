module VCAP::CloudController
  class ProcessFetcher
    class << self
      def fetch_for_app_by_type(process_type:, app_guid:)
        app = AppModel.where(guid: app_guid).first
        return nil unless app

        process = app.processes_dataset.where(type: process_type).last
        [process, app, app.space]
      end

      def fetch(process_guid:)
        process = ProcessModel.where(guid: process_guid).first
        return nil unless process

        [process, process.space]
      end

      # Fetches all processes in a given space along with their app GUIDs
      # @param space_guid [String] The GUID of the space
      # @return [Array<ProcessModel>] List of processes in the space
      def fetch_for_space(space_guid:)
          ProcessModel
            .join(:apps, guid: :app_guid)
            .where(apps__space_guid: space_guid)
            .all
      end
    end
  end
end
