module VCAP::CloudController
  class ProcessPresenter
    attr_reader :process

    def initialize(process)
      @process = process
    end

    def present_json
      process_hash = {
        guid: process.guid,
        type: process.type,
      }

      MultiJson.dump(process_hash, pretty: true)
    end
  end
end
