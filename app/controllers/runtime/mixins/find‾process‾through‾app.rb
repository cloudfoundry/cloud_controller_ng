module VCAP::CloudController
  module FindProcessThroughApp
    def find_guid(guid, model=ProcessModel)
      if model == ProcessModel
        web_process = AppModel.find(guid: guid).try(:newest_web_process)
        raise self.class.not_found_exception(guid, AppModel) if web_process.nil?

        web_process
      else
        super
      end
    end
  end
end
