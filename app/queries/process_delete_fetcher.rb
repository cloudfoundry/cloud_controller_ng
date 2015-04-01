module VCAP::CloudController
  class ProcessDeleteFetcher
    def fetch(process_guid)
      process_dataset = App.where(guid: process_guid).eager(:space)
      return nil if process_dataset.empty?

      space = process_dataset.first.space
      [process_dataset, space]
    end
  end
end
