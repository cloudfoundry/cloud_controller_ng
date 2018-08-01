module VCAP::CloudController
  class ProcessFetcher
    def fetch_for_app_by_type(process_type:, app_guid:)
      app = AppModel.where(guid: app_guid).eager(:space, :organization).all.first
      return nil unless app
      process = app.processes_dataset.where(type: process_type).first
      [process, app, app.space, app.organization]
    end

    def fetch(process_guid:)
      process = ProcessModel.where(guid: process_guid).eager(:space, :organization).all.first
      return nil unless process
      [process, process.space, process.organization]
    end
  end
end
