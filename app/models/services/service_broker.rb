module VCAP::CloudController
  class ServiceBroker < Sequel::Model
    one_to_many :services
    one_to_many :service_dashboard_client

    one_to_many :labels, class: 'VCAP::CloudController::ServiceBrokerLabelModel', key: :resource_guid, primary_key: :guid
    one_to_many :annotations, class: 'VCAP::CloudController::ServiceBrokerAnnotationModel', key: :resource_guid, primary_key: :guid
    add_association_dependencies labels: :destroy
    add_association_dependencies annotations: :destroy

    many_to_one :space

    import_attributes :name, :broker_url, :auth_username, :auth_password
    export_attributes :name, :broker_url, :auth_username, :space_guid

    add_association_dependencies services: :destroy
    add_association_dependencies service_dashboard_client: :nullify

    many_to_many :service_plans, join_table: :services, right_key: :id, right_primary_key: :service_id

    set_field_as_encrypted :auth_password

    def validate
      validates_presence :name
      validates_presence :broker_url
      validates_presence :auth_username
      validates_presence :auth_password
      validates_unique :name, message: Sequel.lit('Name must be unique')
      validates_url :broker_url
      validates_url_no_basic_auth
    end

    def client
      @client ||= VCAP::Services::ServiceBrokers::V2::Client.new(url: broker_url, auth_username: auth_username, auth_password: auth_password)
    end

    def in_transitional_state?
      [ServiceBrokerStateEnum::SYNCHRONIZING, ServiceBrokerStateEnum::DELETE_IN_PROGRESS].include?(self.state)
    end

    def available?
      self.state.blank? || self.state == ServiceBrokerStateEnum::AVAILABLE
    end

    def space_scoped?
      !!space_id
    end

    def has_service_instances?
      VCAP::CloudController::ServiceInstance.
        join(:service_plans, id: :service_plan_id).
        join(:services, id: :service_id).
        where(services__service_broker_id: id).
        any?
    end

    def self.user_visibility_filter(user)
      { space: user.spaces_dataset }
    end

    private

    def validates_url_no_basic_auth
      errors.add(:broker_url, :basic_auth) if URI(broker_url).userinfo
    rescue ArgumentError, URI::InvalidURIError
    end
  end
end
