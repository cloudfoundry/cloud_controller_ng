module CCInitializers
  def self.app_soft_delete_destroyer(_)
    VCAP::CloudController::App.where(not_deleted: nil).delete
  end
end
