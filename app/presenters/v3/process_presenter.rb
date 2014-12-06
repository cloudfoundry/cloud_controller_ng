module VCAP::CloudController
  class ProcessPresenter
    def present_json(process)
      MultiJson.dump(process_hash(process), pretty: true)
    end

    def present_json_list(processes)
      process_hashes = processes.collect { |process| process_hash(process) }
      MultiJson.dump(process_hashes, pretty: true)
    end

    private

    def process_hash(process)
      {
        guid: process.guid,
        type: process.type,
      }
    end
  end
end
