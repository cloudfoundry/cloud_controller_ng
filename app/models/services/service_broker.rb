module VCAP::CloudController::Models
  class ServiceBroker < Sequel::Model
    import_attributes :name, :broker_url, :token
    export_attributes :name, :broker_url

    def self.user_visibility_filter(user)
      user_visibility_filter_with_admin_override(id: []) # awful hack: non-admins see no records
    end

    def validate
      validates_presence :name
      validates_presence :broker_url
      validates_presence :token
      validates_unique :name
      validates_unique :broker_url
    end
  end
end
