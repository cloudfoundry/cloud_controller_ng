require "spec_helper"

module VCAP::CloudController
  describe ManagedServiceInstance, type: :model do
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make }
    let(:email) { Sham.email }
    let(:guid) { Sham.guid }

    after { VCAP::Request.current_id = nil }

    before do
      VCAP::CloudController::SecurityContext.stub(:current_user_email) { email }

      client = double('broker client', unbind: nil, deprovision: nil)
      Service.any_instance.stub(:client).and_return(client)
    end

    it_behaves_like "a CloudController model", {
      required_attributes: [:name, :service_plan, :space],
      db_required_attributes: [:name],
      unique_attributes: [[:space, :name]],
      custom_attributes_for_uniqueness_tests: -> { {service_plan: ServicePlan.make} },
      stripped_string_attributes: :name,
      many_to_one: {
        service_plan: {
          create_for: lambda { |service_instance| ServicePlan.make },
        },
        space: {
          delete_ok: true,
          create_for: lambda { |service_instance| Space.make },
        }
      },
      one_to_zero_or_more: {
        service_bindings: {
          delete_ok: true,
          create_for: lambda { |service_instance|
            make_service_binding_for_service_instance(service_instance)
          }
        }
      }
    }

    describe "#create" do
      it 'has a guid when constructed' do
        instance = described_class.new
        expect(instance.guid).to be
      end

      it "saves with is_gateway_service true" do
        instance = described_class.make
        instance.refresh.is_gateway_service.should == true
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

    describe "serialization" do
      let(:dashboard_url) { 'http://dashboard.io' }

      it "allows export of dashboard_url" do
        service_instance.dashboard_url = dashboard_url
        Yajl::Parser.parse(service_instance.to_json).fetch("dashboard_url").should == dashboard_url
      end

      it "includes its type" do
        expect(Yajl::Parser.parse(service_instance.to_json).fetch("type")).to eq "managed_service_instance"
      end
    end

    describe "lifecycle" do
      context "service deprovisioning" do
        it "should deprovision a service on destroy" do
          service_instance.client.should_receive(:deprovision).with(service_instance)
          service_instance.destroy(savepoint: true)
        end
      end

      context "when deprovision fails" do
        it "should raise and rollback" do
          service_instance.client.stub(:deprovision).and_raise
          expect {
            service_instance.destroy(savepoint: true)
          }.to raise_error
          VCAP::CloudController::ManagedServiceInstance.find(id: service_instance.id).should be
        end
      end
    end

    context "billing" do
      context "creating a service instance" do
        it "should call ServiceCreateEvent.create_from_service_instance" do
          ServiceCreateEvent.should_receive(:create_from_service_instance)
          ServiceDeleteEvent.should_not_receive(:create_from_service_instance)
          service_instance
        end
      end

      context "destroying a service instance" do
        it "should call ServiceDeleteEvent.create_from_service_instance" do
          service_instance
          ServiceCreateEvent.should_not_receive(:create_from_service_instance)
          ServiceDeleteEvent.should_receive(:create_from_service_instance).with(service_instance)
          service_instance.destroy(savepoint: true)
        end
      end
    end

    describe "#as_summary_json" do
      let(:service) { Service.make(label: "YourSQL", guid: "9876XZ", provider: "Bill Gates", version: "1.2.3") }
      let(:service_plan) { ServicePlan.make(name: "Gold Plan", guid: "12763abc", service: service) }
      subject(:service_instance) { ManagedServiceInstance.make(service_plan: service_plan) }

      it 'returns detailed summary' do
        service_instance.dashboard_url = 'http://dashboard.example.com'

        service_instance.as_summary_json.should == {
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
        }
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

      context "with a free quota" do
        let(:org) { Organization.make(:quota_definition => free_quota) }
        let(:space) { Space.make(:organization => org) }

        context "when the service instance is not associated with a free plan" do
          it "raises an error" do
            expect {
              ManagedServiceInstance.make(space: space, service_plan: paid_plan)
            }.to raise_error(Sequel::ValidationFailed, /service_plan paid_services_not_allowed/)
          end
        end
      end

      context "exceed quota" do
        it "should raise paid quota error when paid quota is exceeded" do
          org = Organization.make(:quota_definition => paid_quota)
          space = Space.make(:organization => org)
          ManagedServiceInstance.make(:space => space,
                                              :service_plan => free_plan).
            save(:validate => false)
          space.refresh
          expect do
            ManagedServiceInstance.make(:space => space,
                                                :service_plan => free_plan)
          end.to raise_error(Sequel::ValidationFailed, /org paid_quota_exceeded/)
        end

        it "should raise free quota error when free quota is exceeded" do
          org = Organization.make(:quota_definition => free_quota)
          space = Space.make(:organization => org)
          ManagedServiceInstance.make(:space => space,
                                              :service_plan => free_plan).
            save(:validate => false)
          space.refresh
          expect do
            ManagedServiceInstance.make(:space => space,
                                                :service_plan => free_plan)
          end.to raise_error(Sequel::ValidationFailed, /org free_quota_exceeded/)
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
                             /service_plan paid_services_not_allowed/)
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
      subject { service_instance.destroy(savepoint: true) }

      it "destroys the service bindings" do
        service_binding = ServiceBinding.make(
          :app => AppFactory.make(:space => service_instance.space),
          :service_instance => service_instance
        )
        expect { subject }.to change { ServiceBinding.where(:id => service_binding.id).count }.by(-1)
      end
    end

    describe "validations" do
      it "should not bind an app and a service instance from different app spaces" do
        AppFactory.make(:space => service_instance.space)
        service_binding = ServiceBinding.make
        expect {
          service_instance.add_service_binding(service_binding)
        }.to raise_error ServiceInstance::InvalidServiceBinding
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
          subject.service_plan.service.service_auth_token.destroy(savepoint: true)
          subject.refresh
          expect do
            subject.enum_snapshots
          end.to raise_error(VCAP::Errors::ApiError, /Missing service auth token/)
        end
      end

      context "returns a list of snapshots" do
        let(:success_response) { Yajl::Encoder.encode({snapshots: [{snapshot_id: '1', name: 'foo', state: 'ok', size: 0},
                                                                   {snapshot_id: '2', name: 'bar', state: 'bad', size: 0}]}) }
        before do
          stub_request(:get, enum_snapshots_url_matcher).to_return(:body => success_response)
        end

        it "return a list of snapshot from the gateway" do
          snapshots = subject.enum_snapshots
          snapshots.should have(2).items
          snapshots.first.snapshot_id.should == '1'
          snapshots.first.state.should == 'ok'
          snapshots.last.snapshot_id.should == '2'
          snapshots.last.state.should == 'bad'
          a_request(:get, enum_snapshots_url_matcher).with(:headers => {
            "Content-Type" => "application/json",
            "X-Vcap-Service-Token" => "tokenvalue"
          }).should have_been_made
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
          subject.service_plan.service.service_auth_token.destroy(savepoint: true)
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
          snapshot.snapshot_id.should == '1'
          snapshot.state.should == 'empty'
          a_request(:post, create_snapshot_url_matcher).should have_been_made
        end

        it "uses the correct svc auth token" do
          subject.create_snapshot(name)

          a_request(:post, create_snapshot_url_matcher).with(
            headers: {"X-VCAP-Service-Token" => 'tokenvalue'}).should have_been_made
        end

        it "has the name in the payload" do
          payload = Yajl::Encoder.encode({name: name})
          subject.create_snapshot(name)

          a_request(:post, create_snapshot_url_matcher).with(:body => payload).should have_been_made
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

        specify { service_instance.should be_bindable }
      end

      context "when the service is not bindable" do
        let(:service) { Service.make(bindable: false) }

        specify { service_instance.should_not be_bindable }
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

