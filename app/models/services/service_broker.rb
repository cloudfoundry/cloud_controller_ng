module VCAP::CloudController
  class ServiceBroker < Sequel::Model
  end

  require 'models/services/service_broker/v2/catalog'

  class ServiceBroker
    one_to_many :services

    import_attributes :name, :broker_url, :auth_username, :auth_password
    export_attributes :name, :broker_url, :auth_username

    add_association_dependencies :services => :destroy

    many_to_many :service_plans, :join_table => :services, :right_key => :id, :right_primary_key => :service_id

    def validate
      validates_presence :name
      validates_presence :broker_url
      validates_presence :auth_username
      validates_presence :auth_password
      validates_unique :name
      validates_unique :broker_url
      validates_url :broker_url
    end

    def auth_password
      return unless super
      VCAP::CloudController::Encryptor.decrypt(super, salt)
    end

    def auth_password=(value)
      generate_salt

      # Encryptor cannot encrypt an empty string
      if value.blank?
        super(nil)
      else
        super(VCAP::CloudController::Encryptor.encrypt(value, salt))
      end
    end

    def generate_salt
      self.salt ||= VCAP::CloudController::Encryptor.generate_salt
    end

    def client
      @client ||= ServiceBroker::V2::Client.new(url: broker_url, auth_username: auth_username, auth_password: auth_password)
    end
  end
end
