module CCInitializers
  def self.app_soft_delete_destroyer(_)
    deleted_app_id_ref = VCAP::CloudController::App.where(not_deleted: nil).select(:id)
    VCAP::CloudController::AppEvent.where(app_id: deleted_app_id_ref).delete
    VCAP::CloudController::App.where(not_deleted: nil).delete
  end
end
