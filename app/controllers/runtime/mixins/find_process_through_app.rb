module VCAP::CloudController
  module FindProcessThroughApp
    def find_guid(guid, model=ProcessModel)
      if model == ProcessModel
        obj = AppModel.find(guid: guid).try(:web_process)
        raise self.class.not_found_exception(guid, AppModel) if obj.nil?
        obj
      else
        super
      end
    end
  end
end
