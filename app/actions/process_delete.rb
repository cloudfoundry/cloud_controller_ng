module VCAP::CloudController
  class ProcessDelete
    def delete(process, user, user_email)
      app_model = AppModel.find(guid: process.app_guid)
      space = Space.find(guid: app_model.space_guid)
      Repositories::Runtime::AppEventRepository.new.record_app_delete_request(process, space, user, user_email, true)
      process.destroy
    end
  end
end
