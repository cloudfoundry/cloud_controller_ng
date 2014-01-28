require 'vcap/request'

module VCAP::CloudController
  class ManagedServiceInstance < ServiceInstance
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

    default_order_by  :id

    many_to_one :service_plan

    export_attributes :name, :credentials, :service_plan_guid,
      :space_guid, :gateway_data, :dashboard_url, :type

    import_attributes :name, :service_plan_guid,
      :space_guid, :gateway_data

    strip_attributes  :name

    plugin :after_initialize

    # This only applies to V1 services
    alias_attribute :broker_provided_id, :gateway_name

    delegate :client, to: :service_plan

    add_association_dependencies :service_bindings => :destroy

    def validate
      super
      validates_presence :service_plan
      check_quota
    end

    def after_create
      super
      ServiceCreateEvent.create_from_service_instance(self)
    end

    def after_destroy
      super

      client.deprovision(self)

      ServiceDeleteEvent.create_from_service_instance(self)
    end

    def after_initialize
      super
      self.guid ||= SecureRandom.uuid
    end

    def as_summary_json
      super.merge(
        'dashboard_url' => dashboard_url,
        'service_plan' => {
          'guid' => service_plan.guid,
          'name' => service_plan.name,
          'service' => {
            'guid' => service.guid,
            'label' => service.label,
            'provider' => service.provider,
            'version' => service.version,
          }
        }
      )
    end

    def check_quota
      if space
        unless service_plan
          errors.add(:space, :quota_exceeded)
          return
        end

        MaxServiceInstancePolicy.new(organization, self).check_quota
      end
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

    def requester
      VCAP::Services::Api::SynchronousHttpRequest
    end

    def service
      service_plan.service
    end

    def create_snapshot(name)
      NGServiceGatewayClient.new(service, gateway_name).create_snapshot(name)
    end

    def enum_snapshots
      NGServiceGatewayClient.new(service, gateway_name).enum_snapshots
    end

    def logger
      @logger ||= Steno.logger("cc.models.service_instance")
    end

    def bindable?
      service_plan.bindable?
    end

    def tags
      service.tags
    end
  end
end
