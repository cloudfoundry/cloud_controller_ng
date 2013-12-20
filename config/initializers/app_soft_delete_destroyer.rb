module CCInitializers
  def self.app_soft_delete_destroyer(_)
    # We need to purge soft deleted apps. But we cannot do it in a migration because other
    # running CC's might still be creating soft deleted apps while the migration is running
    # This needs to persist until all CC's are no longer soft deleting apps which could
    # be a while because of on premise installs.
    app_klass = VCAP::CloudController::App
    deleted_app_id_ref = app_klass.where(not_deleted: nil).select(:id)
    VCAP::CloudController::AppEvent.where(app_id: deleted_app_id_ref).delete
    Sequel::Model.db[:apps_routes].where(app_id: deleted_app_id_ref).delete
    app_klass.where(not_deleted: nil).delete
  end
end
