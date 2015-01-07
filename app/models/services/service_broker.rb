module VCAP::CloudController
  class ServiceBroker < Sequel::Model
    one_to_many :services
    one_to_many :service_dashboard_client

    import_attributes :name, :broker_url, :auth_username, :auth_password
    export_attributes :name, :broker_url, :auth_username

    add_association_dependencies services: :destroy
    add_association_dependencies service_dashboard_client: :nullify

    many_to_many :service_plans, join_table: :services, right_key: :id, right_primary_key: :service_id

    encrypt :auth_password, salt: :salt

    def validate
      validates_presence :name
      validates_presence :broker_url
      validates_presence :auth_username
      validates_presence :auth_password
      validates_unique :name
      validates_unique :broker_url
      validates_url :broker_url
    end

    def client
      @client ||= VCAP::Services::ServiceBrokers::V2::Client.new(url: broker_url, auth_username: auth_username, auth_password: auth_password)
    end
  end
end
