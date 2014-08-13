require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::ServiceBinding, type: :model do
    let(:client) { double('broker client', unbind: nil, deprovision: nil) }

    before do
      allow_any_instance_of(Service).to receive(:client).and_return(client)
    end

    it { is_expected.to have_timestamp_columns }

    describe "Associations" do
      it { is_expected.to have_associated :app }
      it { is_expected.to have_associated :service_instance }
    end

    describe "Validations" do
      it { is_expected.to validate_presence :app }
      it { is_expected.to validate_presence :service_instance }
      it { is_expected.to validate_db_presence :credentials }
      it { is_expected.to validate_uniqueness [:app_id, :service_instance_id] }
    end

    describe "Serialization" do
      it { is_expected.to export_attributes :app_guid, :service_instance_guid, :credentials, :binding_options,
                                    :gateway_data, :gateway_name, :syslog_drain_url }
      it { is_expected.to import_attributes :app_guid, :service_instance_guid, :credentials,
                                    :binding_options, :gateway_data, :syslog_drain_url }
    end

    describe "#create" do
      it 'has a guid when constructed' do
        binding = described_class.new
        expect(binding.guid).to be
      end
    end

    describe "#destroy" do
      let(:binding) { ServiceBinding.make }
      it "unbinds at the broker" do
        expect(binding.client).to receive(:unbind)
        binding.destroy
      end

      context 'when unbind fails' do
        before { allow(binding.client).to receive(:unbind).and_raise }

        it 'raises an error and rolls back' do
          expect {
            binding.destroy
          }.to raise_error

          expect(binding).to be_exists
        end
      end
    end

    it_behaves_like "a model with an encrypted attribute" do
      let(:service_instance) { ManagedServiceInstance.make }

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
        @app = AppFactory.make
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

    describe '#in_suspended_org?' do
      let(:app) { VCAP::CloudController::App.make }
      subject(:service_binding) {  VCAP::CloudController::ServiceBinding.new(app: app) }

      context 'when in a suspended organization' do
        before { allow(app).to receive(:in_suspended_org?).and_return(true) }
        it 'is true' do
          expect(service_binding).to be_in_suspended_org
        end
      end

      context 'when in an unsuspended organization' do
        before { allow(app).to receive(:in_suspended_org?).and_return(false) }
        it 'is false' do
          expect(service_binding).not_to be_in_suspended_org
        end
      end
    end

    describe "logging service bindings" do
      let(:service) { Service.make }
      let(:service_plan) { ServicePlan.make(:service => service) }
      let(:service_instance) do
        ManagedServiceInstance.make(
          :service_plan => service_plan,
          :name => "not a syslog drain instance"
        )
      end

      context "service that does not require syslog_drain" do
        let(:service) { Service.make(:requires => []) }

        it "should not allow a non syslog_drain with a syslog drain url" do
          expect {
            service_binding = ServiceBinding.make(:service_instance => service_instance)
            service_binding.syslog_drain_url = "http://this.is.a.mean.url.com"
            service_binding.save
          }.to raise_error(VCAP::Errors::ApiError, /Service is not advertised as a logging service. Please contact the service provider./)
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

      context "service that does require a syslog_drain" do
        let(:service) { Service.make(:requires => ["syslog_drain"]) }

        it "should allow a syslog_drain with a syslog drain url" do
          expect {
            service_binding = ServiceBinding.make(:service_instance => service_instance)
            service_binding.syslog_drain_url = "http://syslogurl.com"
            service_binding.save
          }.not_to raise_error
        end
      end
    end

    describe "restaging" do
      def fake_app_staging(app)
        app.package_hash = "abc"
        app.add_new_droplet("def")
        app.mark_as_staged
        app.save
        expect(app.needs_staging?).to eq(false)
      end

      let(:app) do
        app = AppFactory.make
        app.state = "STARTED"
        app.instances = 1
        fake_app_staging(app)
        app
      end

      let(:service_instance) { ManagedServiceInstance.make(:space => app.space) }

      it "should not trigger restaging when creating a binding" do
        ServiceBinding.make(:app => app, :service_instance => service_instance)
        app.refresh
        expect(app.needs_staging?).to be false
      end

      it "should not trigger restaging when directly destroying a binding" do
        binding = ServiceBinding.make(:app => app, :service_instance => service_instance)
        app.refresh
        fake_app_staging(app)
        expect(app.needs_staging?).to be false

        binding.destroy
        app.refresh
        expect(app.needs_staging?).to be false
      end

      it "should not trigger restaging when indirectly destroying a binding" do
        binding = ServiceBinding.make(:app => app, :service_instance => service_instance)
        app.refresh
        fake_app_staging(app)
        expect(app.needs_staging?).to be false

        app.remove_service_binding(binding)
        expect(app.needs_staging?).to be false
      end
    end

    describe '#bind!' do
      let(:binding) { ServiceBinding.make }

      before do
        allow(client).to receive(:bind)
        allow(binding).to receive(:save)
      end

      it 'sends a bind request to the broker' do
        binding.bind!

        expect(client).to have_received(:bind).with(binding)
      end

      it 'saves the binding to the database' do
        binding.bind!

        expect(binding).to have_received(:save)
      end

      context 'when sending a bind request to the broker raises an error' do
        before do
          allow(client).to receive(:bind).and_raise(StandardError.new('bind_error'))
        end

        it 'raises the bind error' do
          expect { binding.bind! }.to raise_error(/bind_error/)
        end
      end

      context 'when the model save raises an error' do
        before do
          allow(binding).to receive(:save).and_raise(StandardError.new('save'))
          allow(client).to receive(:unbind)
        end

        it 'sends an unbind request to the broker' do
          binding.bind! rescue nil

          expect(client).to have_received(:unbind).with(binding)
        end

        it 'raises the save error' do
          expect { binding.bind! }.to raise_error(/save/)
        end

        context 'and the unbind also raises an error' do
          let(:logger) { double('logger') }

          before do
            allow(client).to receive(:unbind).and_raise(StandardError.new('unbind_error'))
            allow(binding).to receive(:logger).and_return(logger)
            allow(logger).to receive(:error)
          end

          it 'logs the unbind error' do
            binding.bind! rescue nil
            expect(logger).to have_received(:error).with(/Unable to unbind.*unbind_error/)
          end

          it 'raises the save error' do
            expect { binding.bind! }.to raise_error(/save/)
          end
        end
      end
    end

    describe "#to_hash" do
      let(:binding) { ServiceBinding.make }
      let(:developer) { make_developer_for_space(binding.service_instance.space) }
      let(:auditor) { make_auditor_for_space(binding.service_instance.space) }
      let(:user) { make_user_for_space(binding.service_instance.space) }

      it "does not redact creds for an admin" do
        allow(VCAP::CloudController::SecurityContext).to receive(:admin?).and_return(true)
        expect(binding.to_hash['credentials']).not_to eq({ :redacted_message => '[PRIVATE DATA HIDDEN]' })
      end

      it "does not redact creds for a space developer" do
        allow(VCAP::CloudController::SecurityContext).to receive(:current_user).and_return(developer)
        expect(binding.to_hash['credentials']).not_to eq({ :redacted_message => '[PRIVATE DATA HIDDEN]' })
      end

      it "redacts creds for a space auditor" do
        allow(VCAP::CloudController::SecurityContext).to receive(:current_user).and_return(auditor)
        expect(binding.to_hash['credentials']).to eq({ :redacted_message => '[PRIVATE DATA HIDDEN]' })
      end

      it "redacts creds for a space user" do
        allow(VCAP::CloudController::SecurityContext).to receive(:current_user).and_return(user)
        expect(binding.to_hash['credentials']).to eq({ :redacted_message => '[PRIVATE DATA HIDDEN]' })
      end
    end
  end
end
