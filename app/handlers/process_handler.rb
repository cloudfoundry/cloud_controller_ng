module VCAP::CloudController
  class ProcessHandler
    def find_by_guid(guid)
      process_model = ProcessModel.find(guid: guid)
      return if process_model.nil?
      AppProcess.new(process_model)
    end
  end
end
