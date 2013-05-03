require "services/api"

module VCAP::CloudController::Models
  class ServiceInstance < Sequel::Model
    class InvalidServiceBinding < StandardError; end
    class MissingServiceAuthToken < StandardError; end
    class ServiceGatewayError < StandardError; end

    class NGServiceGatewayClient
      attr_accessor :service, :token, :service_id

      def initialize(service, service_id)
        @service = service
        @token   = service.service_auth_token
        @service_id = service_id
        unless token
          raise MissingServiceAuthToken, "ServiceAuthToken not found for service #{service}"
        end
      end

      def create_snapshot(name)
        payload = VCAP::Services::Api::CreateSnapshotV2Request.new(:name => name).encode
        response = do_request(:post, payload)
        VCAP::Services::Api::SnapshotV2.decode(response)
      end

      def enum_snapshots
        list = VCAP::Services::Api::SnapshotListV2.decode(do_request(:get))
        list.snapshots.collect{|e| VCAP::Services::Api::SnapshotV2.new(e) }
      end

      private

      def do_request(method, payload=nil)
        client = HTTPClient.new
        u = URI.parse(service.url)
        u.path = "/gateway/v2/configurations/#{service_id}/snapshots"

        response = client.public_send(method, u,
                                      :header => { VCAP::Services::Api::GATEWAY_TOKEN_HEADER => token.token,
                                                   "Content-Type" => "application/json"
                                                },
                                      :body   => payload)
        if response.ok?
          response.body
        else
          raise ServiceGatewayError, "Service gateway upstream failure, responded with #{response.status}: #{response.body}"
        end
      end
    end

    class << self
      def gateway_client_class
        @gateway_client_class || VCAP::Services::Api::ServiceGatewayClient
      end

      def gateway_client_class=(klass)
        raise ArgumentError, "gateway_client_class must not be nil" unless klass
        @gateway_client_class = klass
      end
    end

    many_to_one :service_plan
    many_to_one :space
    one_to_many :service_bindings, :before_add => :validate_service_binding

    add_association_dependencies :service_bindings => :destroy

    attr_reader :provisioned_on_gateway_for_plan

    default_order_by  :id

    export_attributes :name, :credentials, :service_plan_guid,
                      :space_guid, :gateway_data

    import_attributes :name, :service_plan_guid,
                      :space_guid, :gateway_data

    strip_attributes  :name

    def validate
      validates_presence :name
      validates_presence :space
      validates_presence :service_plan
      validates_unique   [:space_id, :name]
      check_quota
    end

    def before_create
      super
      provision_on_gateway
    end

    def after_create
      super
      ServiceCreateEvent.create_from_service_instance(self)
    end

    def after_destroy
      super
      deprovision_on_gateway
      ServiceDeleteEvent.create_from_service_instance(self)
    end

    def after_commit
      @provisioned_on_gateway_for_plan = nil
      super
    end

    def after_rollback
      deprovision_on_gateway if @provisioned_on_gateway_for_plan
      super
    end

    def validate_service_binding(service_binding)
      if service_binding && service_binding.app.space != space
        # FIXME: unlike most other validations, this is *NOT* being enforced
        # by the underlying db.
        raise InvalidServiceBinding.new(service_binding.id)
      end
    end

    def as_summary_json
      {
        :guid => guid,
        :name => name,
        :bound_app_count => service_bindings_dataset.count,
        :service_plan => {
          :guid => service_plan.guid,
          :name => service_plan.name,
          :service => {
            :guid => service.guid,
            :label => service.label,
            :provider => service.provider,
            :version => service.version,
          }
        }
      }
    end

    def check_quota
      if space
        if !space.organization.service_instance_quota_remaining?
          if space.organization.paid_services_allowed?
            errors.add(:space, :paid_quota_exceeded)
          else
            errors.add(:space, :free_quota_exceeded)
          end
        end

        # Is a paid service instance being created
        # when the org doesn't allow it?
        if service_plan && !service_plan.free
          unless space.organization.paid_services_allowed?
            errors.add(:service_plan, :paid_services_not_allowed)
          end
        end
      end
    end

    def credentials=(val)
      json = Yajl::Encoder.encode(val)
      generate_salt
      encrypted_string = VCAP::CloudController::Encryptor.encrypt(json, salt)
      super(encrypted_string)
    end

    def credentials
      return unless super
      json = VCAP::CloudController::Encryptor.decrypt(super, salt)
      Yajl::Parser.parse(json) if json
    end

    def gateway_data=(val)
      str = Yajl::Encoder.encode(val)
      super(str)
    end

    def gateway_data
      val = super
      val = Yajl::Parser.parse(val) if val
      val
    end

    def self.user_visibility_filter(user)
      user_visibility_filter_with_admin_override(
        :space => user.spaces_dataset)
    end

    def requester
      VCAP::Services::Api::SynchronousHttpRequest
    end

    def service_gateway_client(plan = service_plan)
      @client ||= begin
        # This should only happen during unit testing if we are saving without
        # validations to test db constraints
        return unless plan

        raise InvalidServiceBinding.new("no service_auth_token") unless plan.service.service_auth_token

        self.class.gateway_client_class.new(
          plan.service.url,
          plan.service.service_auth_token.token,
          plan.service.timeout,
          :requester => requester
        )
      end
    end

    def service
      service_plan.service
    end

    def provision_on_gateway
      logger.debug "provisioning service for instance #{guid}"

      gw_attrs = service_gateway_client.provision(
        # TODO: we shouldn't still be using this compound label
        :label => "#{service.label}-#{service.version}",
        :name  => name,
        :email => VCAP::CloudController::SecurityContext.current_user_email,
        :plan  => service_plan.name,
        :plan_option => {}, # TODO: remove this
        :version => service.version,
        :provider => service.provider,
        :space_guid => space.guid,
        :organization_guid => space.organization_guid,
        :unique_id => service_plan.unique_id,
      )

      logger.debug "provision response for instance #{guid} #{gw_attrs.inspect}"

      self.gateway_name = gw_attrs.service_id
      self.gateway_data = gw_attrs.configuration
      self.credentials  = gw_attrs.credentials

      @provisioned_on_gateway_for_plan = service_plan
    end

    def deprovision_on_gateway
      plan = @provisioned_on_gateway_for_plan || service_plan
      return unless service_gateway_client(plan) # TODO: see service_gateway_client
      @provisioned_on_gateway_for_plan = nil
      service_gateway_client(plan).unprovision(:service_id => gateway_name)
    rescue => e
      logger.error "deprovision failed #{e}"
    end

    def create_snapshot(name)
      NGServiceGatewayClient.new(service, gateway_name).create_snapshot(name)
    end

    def enum_snapshots
      NGServiceGatewayClient.new(service, gateway_name).enum_snapshots
    end

    def snapshot_details(sid)
      service_gateway_client.snapshot_details(:service_id => gateway_name, :snapshot_id => sid)
    end

    def rollback_snapshot(sid)
      service_gateway_client.rollback_snapshot(:service_id => gateway_name, :snapshot_id => sid)
    end

    def delete_snapshot(sid)
      service_gateway_client.delete_snapshot(:service_id => gateway_name, :snapshot_id => sid)
    end

    def serialized_url(sid)
      service_gateway_client.serialized_url(:service_id => gateway_name, :snapshot_id => sid)
    end

    def create_serialized_url(sid)
      service_gateway_client.create_serialized_url(:service_id => gateway_name, :snapshot_id => sid)
    end

    def import_from_url(req)
      service_gateway_client.import_from_url(:service_id => gateway_name, :msg => req)
    end

    def job_info(job_id)
      service_gateway_client.job_info(:service_id => gateway_name, :job_id => job_id)
    end

    def logger
      @logger ||= Steno.logger("cc.models.service_instance")
    end

    def generate_salt
      self.salt ||= VCAP::CloudController::Encryptor.generate_salt
    end
  end
end
