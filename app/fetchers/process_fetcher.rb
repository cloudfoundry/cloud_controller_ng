module VCAP::CloudController
  class ProcessFetcher
    class << self
      def fetch_for_app_by_type(process_type:, app_guid:)
        app = AppModel.where(guid: app_guid).first
        return nil unless app

        process = app.processes_dataset.where(type: process_type).last
        [process, app, app.space]
      end

      # Fetches all processes and their spaces for a list of process_guids
      # @param process_guids [Array<String>] List of process GUIDs
      # @return [Array<[ProcessModel, SpaceModel]>] Array of [process, space] pairs
      def fetch_multiple(process_guids:)
        ProcessModel.where(guid: process_guids).all.map { |process| [process, process.space] }
      end

      def fetch(process_guid:)
        process = ProcessModel.where(guid: process_guid).first
        return nil unless process

        [process, process.space]
      end
    end
  end
end
