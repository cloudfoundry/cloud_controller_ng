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
    end
  end
end
