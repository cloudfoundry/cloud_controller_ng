module VCAP::CloudController
  class ProcessScaleFetcher
    def fetch(process_guid)
      process = App.where(guid: process_guid).eager(:space, space: :organization).all.first
      return nil if process.nil?

      org = process.space ? process.space.organization : nil
      [process, process.space, org]
    end
  end
end
