require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::ServiceBinding, :services, type: :model do
    it_behaves_like "a CloudController model", {
      :required_attributes => [:service_instance, :app],
      :db_required_attributes => [:service_instance_id, :app_id, :credentials],
      :unique_attributes => [ [:app, :service_instance] ],
      :create_attribute => lambda { |name|
        @space ||= Space.make
        case name.to_sym
          when :app
            App.make(:space => @space)
          when :service_instance
            ManagedServiceInstance.make(:space => @space)
        end
      },
      :create_attribute_reset => lambda { @space = nil },
      :many_to_one => {
        :app => {
          :delete_ok => true,
          :create_for => lambda { |service_binding|
            App.make(:space => service_binding.space)
          }
        },
        :service_instance => {
          :delete_ok => true,
          :create_for => lambda { |service_binding|
            ManagedServiceInstance.make(:space => service_binding.space)
          }
        }
      }
    }

    describe "#create" do
      it 'has a guid when constructed' do
        binding = described_class.new
        expect(binding.guid).to be
      end
    end

    describe "#destroy" do
      let(:binding) { ServiceBinding.make }
      it "unbinds at the broker" do
        binding.client.should_receive(:unbind)
        binding.destroy
      end
    end

    it_behaves_like "a model with an encrypted attribute" do
      let(:service_instance) { ManagedServiceInstance.make }

      after { service_instance.destroy }

      def new_model
        ServiceBinding.make(
          service_instance: service_instance,
          credentials: value_to_encrypt
        )
      end

      let(:encrypted_attr) { :credentials }
    end

    describe "bad relationships" do
      before do
        # since we don't set them, these will have different app spaces
        @service_instance = ManagedServiceInstance.make
        @app = App.make
        @service_binding = ServiceBinding.make
      end

      it "should not associate an app with a service from a different app space" do
        expect {
          service_binding = ServiceBinding.make
          service_binding.app = @app
          service_binding.save
        }.to raise_error ServiceBinding::InvalidAppAndServiceRelation
      end

      it "should not associate a service with an app from a different app space" do
        expect {
          service_binding = ServiceBinding.make
          service_binding.service_instance = @service_instance
          service_binding.save
        }.to raise_error ServiceBinding::InvalidAppAndServiceRelation
      end
    end

    describe "logging service bindings" do
      let(:service) { Service.make(:requires => []) }
      let(:service_plan) { ServicePlan.make(:service => service) }
      let(:service_instance) do
        ManagedServiceInstance.make(
          :service_plan => service_plan,
          :name => "not a syslog drain instance"
        )
      end

      it "should not allow a non syslog_drain with a syslog drain url" do
        expect {
          service_binding = ServiceBinding.make(:service_instance => service_instance)
          service_binding.syslog_drain_url = "http://this.is.a.mean.url.com"
          service_binding.save
        }.to raise_error(ServiceBinding::InvalidLoggingServiceBinding, "Service is not advertised as a logging service. Please contact the service provider.")
      end

      it "should allow a non syslog_drain with a nil syslog drain url" do
        expect {
          service_binding = ServiceBinding.make(:service_instance => service_instance)
          service_binding.syslog_drain_url = nil
          service_binding.save
        }.not_to raise_error
      end

      it "should allow a non syslog_drain with an empty syslog drain url" do
        expect {
          service_binding = ServiceBinding.make(:service_instance => service_instance)
          service_binding.syslog_drain_url = ""
          service_binding.save
        }.not_to raise_error
      end
    end

    describe "binding" do
      let(:service) { Service.make }
      let(:service_plan) { ServicePlan.make(:service => service) }
      let(:service_instance) do
        ManagedServiceInstance.make(
          :service_plan => service_plan,
          :name => "my-postgresql",
          :space => Space.make,
          :gateway_name => 'gwname_instance',
          :credentials => Sham.service_credentials
        )
      end

      let(:bind_resp) do
        VCAP::Services::Api::GatewayHandleResponse.new(
          :service_id => "gwname_binding",
          :configuration => "abc",
          :credentials => {:password => "foo"}
        )
      end

      context "when the service is unbindable" do
        let(:service) { Service.make(bindable: false) }

        it "raises an UnbindableService" do
          expect {
            ServiceBinding.make(:service_instance => service_instance)
          }.to raise_error(Errors::UnbindableService)
        end
      end
    end

    describe "restaging" do
      let(:app) do
        app = App.make
        app.state = "STARTED"
        app.instances = 1
        fake_app_staging(app)
        app
      end

      let(:service_instance) { ManagedServiceInstance.make(:space => app.space) }

      it "should trigger restaging when creating a binding" do
        ServiceBinding.make(:app => app, :service_instance => service_instance)
        app.refresh
        app.needs_staging?.should be_true
      end

      it "should trigger restaging when directly destroying a binding" do
        binding = ServiceBinding.make(:app => app, :service_instance => service_instance)
        app.refresh
        fake_app_staging(app)
        app.needs_staging?.should be_false

        binding.destroy
        app.refresh
        app.needs_staging?.should be_true
      end

      it "should trigger restaging when indirectly destroying a binding" do
        binding = ServiceBinding.make(:app => app, :service_instance => service_instance)
        app.refresh
        fake_app_staging(app)
        app.needs_staging?.should be_false

        app.remove_service_binding(binding)
        app.needs_staging?.should be_true
      end
    end
  end
end
