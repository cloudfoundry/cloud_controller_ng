module VCAP::CloudController
  class ProcessPresenter
    attr_reader :process

    def initialize(process)
      @process = process
    end

    def present_json
      process_hash = {
        app_guid: process.app_guid,
        guid: process.guid,
      }

      MultiJson.dump(process_hash, pretty: true)
    end
  end
end
