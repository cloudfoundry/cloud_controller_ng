require "spec_helper"

module VCAP::CloudController
  describe ManagedServiceInstance, type: :model do
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make }
    let(:email) { Sham.email }
    let(:guid) { Sham.guid }

    after { VCAP::Request.current_id = nil }

    before do
      allow(VCAP::CloudController::SecurityContext).to receive(:current_user_email) { email }

      client = double('broker client', unbind: nil, deprovision: nil)
      allow_any_instance_of(Service).to receive(:client).and_return(client)
    end

    it { is_expected.to have_timestamp_columns }

    describe "Associations" do
      it { is_expected.to have_associated :service_plan }
      it { is_expected.to have_associated :space }
      it do
        is_expected.to have_associated :service_bindings, associated_instance: ->(service_instance) {
          app = VCAP::CloudController::App.make(:space => service_instance.space)
          ServiceBinding.make(:app => app, :service_instance => service_instance, :credentials => Sham.service_credentials)
        }
      end
    end

    describe "Validations" do
      it { is_expected.to validate_presence :name }
      it { is_expected.to validate_presence :service_plan }
      it { is_expected.to validate_presence :space }
      it { is_expected.to validate_uniqueness [:space_id, :name] }
      it { is_expected.to strip_whitespace :name }

      it "should not bind an app and a service instance from different app spaces" do
        AppFactory.make(:space => service_instance.space)
        service_binding = ServiceBinding.make
        expect {
          service_instance.add_service_binding(service_binding)
        }.to raise_error ServiceInstance::InvalidServiceBinding
      end

      it "validates org and space quotas using MaxServiceInstancePolicy" do
        space_quota_definition = SpaceQuotaDefinition.make
        service_instance.space.space_quota_definition = space_quota_definition
        max_memory_policies = service_instance.validation_policies.select { |policy| policy.instance_of? MaxServiceInstancePolicy }
        expect(max_memory_policies.length).to eq(2)
        targets = max_memory_policies.collect(&:quota_definition)
        expect(targets).to match_array([space_quota_definition, service_instance.organization.quota_definition])
      end

      it "validates org and space quotas using PaidServiceInstancePolicy" do
        space_quota_definition = SpaceQuotaDefinition.make
        service_instance.space.space_quota_definition = space_quota_definition
        policies = service_instance.validation_policies.select { |policy| policy.instance_of? PaidServiceInstancePolicy }
        expect(policies.length).to eq(2)
        targets = policies.collect(&:quota_definition)
        expect(targets).to match_array([space_quota_definition, service_instance.organization.quota_definition])
      end
    end

    describe "Serialization" do
      it { is_expected.to export_attributes :name, :credentials, :service_plan_guid, :space_guid, :gateway_data, :dashboard_url, :type }
      it { is_expected.to import_attributes :name, :service_plan_guid, :space_guid, :gateway_data }
    end

    describe "#create" do
      it 'has a guid when constructed' do
        instance = described_class.new
        expect(instance.guid).to be
      end

      it "saves with is_gateway_service true" do
        instance = described_class.make
        expect(instance.refresh.is_gateway_service).to eq(true)
      end

      it 'creates a CREATED service usage event' do
        instance = described_class.make

        event = ServiceUsageEvent.last
        expect(ServiceUsageEvent.count).to eq(1)
        expect(event.state).to eq(Repositories::Services::ServiceUsageEventRepository::CREATED_EVENT_STATE)
        expect(event).to match_service_instance(instance)
      end
    end

    describe '#delete' do
      it 'creates a DELETED service usage event' do
        instance = described_class.make
        instance.destroy

        event = VCAP::CloudController::ServiceUsageEvent.last

        expect(VCAP::CloudController::ServiceUsageEvent.count).to eq(2)
        expect(event.state).to eq(Repositories::Services::ServiceUsageEventRepository::DELETED_EVENT_STATE)
        expect(event).to match_service_instance(instance)
      end
    end

    describe "lifecycle" do
      context "service deprovisioning" do
        it "should deprovision a service on destroy" do
          expect(service_instance.client).to receive(:deprovision).with(service_instance)
          service_instance.destroy
        end
      end

      context "when deprovision fails" do
        it "should raise and rollback" do
          allow(service_instance.client).to receive(:deprovision).and_raise
          expect {
            service_instance.destroy
          }.to raise_error
          expect(VCAP::CloudController::ManagedServiceInstance.find(id: service_instance.id)).to be
        end
      end
    end

    context "billing" do
      context "creating a service instance" do
        it "should call ServiceCreateEvent.create_from_service_instance" do
          expect(ServiceCreateEvent).to receive(:create_from_service_instance)
          expect(ServiceDeleteEvent).not_to receive(:create_from_service_instance)
          service_instance
        end
      end

      context "destroying a service instance" do
        it "should call ServiceDeleteEvent.create_from_service_instance" do
          service_instance
          expect(ServiceCreateEvent).not_to receive(:create_from_service_instance)
          expect(ServiceDeleteEvent).to receive(:create_from_service_instance).with(service_instance)
          service_instance.destroy
        end
      end
    end

    describe "#as_summary_json" do
      let(:service) { Service.make(label: "YourSQL", guid: "9876XZ", provider: "Bill Gates", version: "1.2.3") }
      let(:service_plan) { ServicePlan.make(name: "Gold Plan", guid: "12763abc", service: service) }
      subject(:service_instance) { ManagedServiceInstance.make(service_plan: service_plan) }

      it 'returns detailed summary' do
        service_instance.dashboard_url = 'http://dashboard.example.com'

        expect(service_instance.as_summary_json).to eq({
          'guid' => subject.guid,
          'name' => subject.name,
          'bound_app_count' => 0,
          'dashboard_url' => 'http://dashboard.example.com',
          'service_plan' => {
            'guid' => '12763abc',
            'name' => 'Gold Plan',
            'service' => {
              'guid' => '9876XZ',
              'label' => 'YourSQL',
              'provider' => 'Bill Gates',
              'version' => '1.2.3',
            }
          }
        })
      end
    end

    context "quota" do
      let(:free_plan) { ServicePlan.make(:free => true) }
      let(:paid_plan) { ServicePlan.make(:free => false) }

      let(:free_quota) do
        QuotaDefinition.make(:total_services => 1,
                                     :non_basic_services_allowed => false)
      end
      let(:paid_quota) do
        QuotaDefinition.make(:total_services => 1,
                                     :non_basic_services_allowed => true)
      end

      context "exceed quota" do
        it "should raise quota error when quota is exceeded" do
          org = Organization.make(:quota_definition => free_quota)
          space = Space.make(:organization => org)
          ManagedServiceInstance.make(:space => space,
                                              :service_plan => free_plan).
            save(:validate => false)
          space.refresh
          expect do
            ManagedServiceInstance.make(:space => space,
                                                :service_plan => free_plan)
          end.to raise_error(Sequel::ValidationFailed, /quota service_instance_quota_exceeded/)
        end

        it "should not raise error when quota is not exceeded" do
          org = Organization.make(:quota_definition => paid_quota)
          space = Space.make(:organization => org)
          expect do
            ManagedServiceInstance.make(:space => space,
                                                :service_plan => free_plan)
          end.to_not raise_error
        end
      end

      context "create free services" do
        it "should not raise error when created in free quota" do
          org = Organization.make(:quota_definition => free_quota)
          space = Space.make(:organization => org)
          expect do
            ManagedServiceInstance.make(:space => space,
                                                :service_plan => free_plan)
          end.to_not raise_error
        end

        it "should not raise error when created in paid quota" do
          org = Organization.make(:quota_definition => paid_quota)
          space = Space.make(:organization => org)
          expect do
            ManagedServiceInstance.make(:space => space,
                                                :service_plan => free_plan)
          end.to_not raise_error
        end
      end

      context "create paid services" do
        it "should raise error when created in free quota" do
          org = Organization.make(:quota_definition => free_quota)
          space = Space.make(:organization => org)
          expect do
            ManagedServiceInstance.make(:space => space,
                                                :service_plan => paid_plan)
          end.to raise_error(Sequel::ValidationFailed,
                             /service_plan paid_services_not_allowed_by_quota/)
        end

        it "should not raise error when created in paid quota" do
          org = Organization.make(:quota_definition => paid_quota)
          space = Space.make(:organization => org)
          expect do
            ManagedServiceInstance.make(:space => space,
                                                :service_plan => paid_plan)
          end.to_not raise_error
        end
      end
    end

    describe "#destroy" do
      subject { service_instance.destroy }

      it "destroys the service bindings" do
        service_binding = ServiceBinding.make(
          :app => AppFactory.make(:space => service_instance.space),
          :service_instance => service_instance
        )
        expect { subject }.to change { ServiceBinding.where(:id => service_binding.id).count }.by(-1)
      end
    end

    describe "#enum_snapshots" do
      subject { ManagedServiceInstance.make() }
      let(:enum_snapshots_url_matcher) { "gw.example.com:12345/gateway/v2/configurations/#{subject.gateway_name}/snapshots" }
      let(:service_auth_token) { "tokenvalue" }
      before do
        subject.service_plan.service.update(:url => "http://gw.example.com:12345/")
        subject.service_plan.service.service_auth_token.update(:token => service_auth_token)
      end

      context "when there isn't a service auth token" do
        it "fails" do
          subject.service_plan.service.service_auth_token.destroy
          subject.refresh
          expect do
            subject.enum_snapshots
          end.to raise_error(VCAP::Errors::ApiError, /Missing service auth token/)
        end
      end

      context "returns a list of snapshots" do
        let(:success_response) { MultiJson.dump({snapshots: [{snapshot_id: '1', name: 'foo', state: 'ok', size: 0},
                                                                   {snapshot_id: '2', name: 'bar', state: 'bad', size: 0}]}) }
        before do
          stub_request(:get, enum_snapshots_url_matcher).to_return(:body => success_response)
        end

        it "return a list of snapshot from the gateway" do
          snapshots = subject.enum_snapshots
          expect(snapshots).to have(2).items
          expect(snapshots.first.snapshot_id).to eq('1')
          expect(snapshots.first.state).to eq('ok')
          expect(snapshots.last.snapshot_id).to eq('2')
          expect(snapshots.last.state).to eq('bad')
          expect(a_request(:get, enum_snapshots_url_matcher).with(:headers => {
            "Content-Type" => "application/json",
            "X-Vcap-Service-Token" => "tokenvalue"
          })).to have_been_made
        end
      end
    end

    describe "#create_snapshot" do
      let(:name) { 'New snapshot' }
      subject { ManagedServiceInstance.make() }
      let(:create_snapshot_url_matcher) { "gw.example.com:12345/gateway/v2/configurations/#{subject.gateway_name}/snapshots" }
      before do
        subject.service_plan.service.update(:url => "http://gw.example.com:12345/")
        subject.service_plan.service.service_auth_token.update(:token => "tokenvalue")
      end

      context "when there isn't a service auth token" do
        it "fails" do
          subject.service_plan.service.service_auth_token.destroy
          subject.refresh
          expect do
            subject.create_snapshot(name)
          end.to raise_error(VCAP::Errors::ApiError, /Missing service auth token/)
        end
      end

      it "rejects empty string as name" do
        expect do
          subject.create_snapshot("")
        end.to raise_error(JsonMessage::ValidationError, /Field: name/)
      end

      context "when the request succeeds" do
        let(:success_response) { %Q({"snapshot_id": "1", "state": "empty", "name": "foo", "size": 0}) }
        before do
          stub_request(:post, create_snapshot_url_matcher).to_return(:body => success_response)
        end

        it "makes an HTTP call to the corresponding service gateway and returns the decoded response" do
          snapshot = subject.create_snapshot(name)
          expect(snapshot.snapshot_id).to eq('1')
          expect(snapshot.state).to eq('empty')
          expect(a_request(:post, create_snapshot_url_matcher)).to have_been_made
        end

        it "uses the correct svc auth token" do
          subject.create_snapshot(name)

          expect(a_request(:post, create_snapshot_url_matcher).with(
            headers: {"X-VCAP-Service-Token" => 'tokenvalue'})).to have_been_made
        end

        it "has the name in the payload" do
          payload = MultiJson.dump({name: name})
          subject.create_snapshot(name)

          expect(a_request(:post, create_snapshot_url_matcher).with(:body => payload)).to have_been_made
        end
      end

      context "when the request fails" do
        it "should raise an error" do
          stub_request(:post, create_snapshot_url_matcher).to_return(:body => "Something went wrong", :status => 500)
          expect { subject.create_snapshot(name) }.to raise_error(ManagedServiceInstance::ServiceGatewayError, /upstream failure/)
        end
      end
    end

    describe "#bindable?" do
      let(:service_instance) { ManagedServiceInstance.make(service_plan: service_plan) }
      let(:service_plan) { ServicePlan.make(service: service) }

      context "when the service is bindable" do
        let(:service) { Service.make(bindable: true) }

        specify { expect(service_instance).to be_bindable }
      end

      context "when the service is not bindable" do
        let(:service) { Service.make(bindable: false) }

        specify { expect(service_instance).not_to be_bindable }
      end
    end

    describe "#tags" do
      let(:service_instance) { ManagedServiceInstance.make(service_plan: service_plan) }
      let(:service_plan) { ServicePlan.make(service: service) }
      let(:service) { Service.make(tags: %w(relational mysql)) }

      it 'gets tags from the service' do
        expect(service_instance.tags).to eq %w(relational mysql)
      end
    end
  end
end

