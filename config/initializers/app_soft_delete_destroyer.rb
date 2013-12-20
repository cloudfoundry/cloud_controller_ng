module CCInitializers
  def self.app_soft_delete_destroyer(_)
    deleted_app_id_ref = VCAP::CloudController::App.where(not_deleted: nil).select(:id)
    VCAP::CloudController::AppEvent.where(app_id: deleted_app_id_ref).delete
    app_klass = VCAP::CloudController::App
    app_klass.db.run("delete from apps_routes where apps_routes.app_id in (#{app_klass.where(not_deleted: nil).select(:id).sql})")
    app_klass.where(not_deleted: nil).delete
  end
end
