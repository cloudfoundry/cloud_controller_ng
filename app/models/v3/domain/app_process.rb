module VCAP::CloudController
  class AppProcess
    attr_reader :guid

    def initialize(process_model)
      @guid = process_model.guid
    end
  end
end
