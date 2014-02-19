require "spec_helper"

module VCAP::CloudController
  describe ServicesController, :services, type: :controller do
    include_examples "uaa authenticated api", path: "/v2/services"
    include_examples "enumerating objects", path: "/v2/services", model: Service
    include_examples "reading a valid object", path: "/v2/services", model: Service,
      basic_attributes: %w(label provider url description version bindable tags requires)
    include_examples "operations on an invalid object", path: "/v2/services"
    include_examples "creating and updating", path: "/v2/services",
                     model: Service,
                     required_attributes: %w(label provider url description version),
                     unique_attributes: %w(label provider),
                     extra_attributes: {extra: ->{Sham.extra}, bindable: false, tags: ["relational"], requires: ["loggyness"]}
    include_examples "deleting a valid object", path: "/v2/services", model: Service,
      one_to_many_collection_ids: {
        :service_plans => lambda { |service| ServicePlan.make(:service => service) },
      }
    include_examples "collection operations", path: "/v2/services", model: Service,
      one_to_many_collection_ids: {
        service_plans: lambda { |service| ServicePlan.make(service: service) }
      },
      many_to_one_collection_ids: {},
      many_to_many_collection_ids: {}

    shared_examples "enumerate and read service only" do |perm_name|
      include_examples "permission enumeration", perm_name,
        :name => 'service',
        :path => "/v2/services",
        :permissions_overlap => true,
        :enumerate => 7
    end

    describe "Permissions" do
      include_context "permissions"

      before do
        5.times { ServicePlan.make }
        @obj_a = ServicePlan.make.service
        @obj_b = ServicePlan.make.service
      end

      let(:creation_req_for_a) do
        Yajl::Encoder.encode(
          :label => Sham.label,
          :provider => Sham.provider,
          :url => Sham.url,
          :description => Sham.description,
          :version => Sham.version)
      end

      let(:update_req_for_a) do
        Yajl::Encoder.encode(:label => Sham.label)
      end

      describe "Org Level Permissions" do
        describe "OrgManager" do
          let(:member_a) { @org_a_manager }
          let(:member_b) { @org_b_manager }

          include_examples "enumerate and read service only", "OrgManager"
        end

        describe "OrgUser" do
          let(:member_a) { @org_a_member }
          let(:member_b) { @org_b_member }

          include_examples "enumerate and read service only", "OrgUser"
        end

        describe "BillingManager" do
          let(:member_a) { @org_a_billing_manager }
          let(:member_b) { @org_b_billing_manager }

          include_examples "enumerate and read service only", "BillingManager"
        end

        describe "Auditor" do
          let(:member_a) { @org_a_auditor }
          let(:member_b) { @org_b_auditor }

          include_examples "enumerate and read service only", "Auditor"
        end
      end

      describe "App Space Level Permissions" do
        describe "SpaceManager" do
          let(:member_a) { @space_a_manager }
          let(:member_b) { @space_b_manager }

          include_examples "enumerate and read service only", "SpaceManager"
        end

        describe "Developer" do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }

          include_examples "enumerate and read service only", "Developer"
        end

        describe "SpaceAuditor" do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }

          include_examples "enumerate and read service only", "SpaceAuditor"
        end
      end
    end

    describe 'GET /v2/services' do
      let(:user) { VCAP::CloudController::User.make }
      let(:headers) { headers_for(user) }

      before do
        @active = 3.times.map do
          Service.make(active: true, long_description: Sham.long_description).tap do |svc|
            ServicePlan.make(service: svc)
          end
        end
        @inactive = 2.times.map do
          Service.make(active: false).tap do |svc|
            ServicePlan.make(service: svc)
          end
        end
      end

      def decoded_guids
        decoded_response["resources"].map { |r| r["metadata"]["guid"] }
      end

      def decoded_long_descriptions
        decoded_response["resources"].map { |r| r["entity"]["long_description"] }
      end

      it "should get all services" do
        get "/v2/services", {}, headers
        last_response.should be_ok
        decoded_guids.should =~ (@active + @inactive).map(&:guid)
      end

      it "has a documentation URL field" do
        get "/v2/services", {}, headers
        decoded_response["resources"].first["entity"].keys.should include "documentation_url"
      end

      it "has a long description field" do
        get "/v2/services", {}, headers
        decoded_long_descriptions.should =~ (@active + @inactive).map(&:long_description)
      end

      context "with an offering that has private plans" do
        before(:each) do
          @svc_all_private = @active.first
          @svc_all_private.service_plans.each{|plan| plan.update(:public => false) }
          @svc_one_public = @active.last
          ServicePlan.make(service: @svc_one_public, public: false)
        end

        it "should remove the offering when I cannot see any of the plans" do
          get "/v2/services", {}, headers
          last_response.should be_ok
          decoded_guids.should include(@svc_one_public.guid)
          decoded_guids.should_not include(@svc_all_private.guid)
        end

        it "should return the offering when I can see at least one of the plans" do
          get "/v2/services", {}, admin_headers
          last_response.should be_ok
          decoded_guids.should include(@svc_one_public.guid)
          decoded_guids.should include(@svc_all_private.guid)
        end
      end

      describe "get /v2/services?q=active:<t|f>" do
        it "can remove inactive services" do
          # Sequel stores 'true' and 'false' as 't' and 'f' in sqlite, so with
          # sqlite, instead of 'true' or 'false', the parameter must be specified
          # as 't' or 'f'. But in postgresql, either way is ok.
          get "/v2/services?q=active:t", {}, headers
          last_response.should be_ok
          decoded_guids.should =~ @active.map(&:guid)
        end

        it "can only get inactive services" do
          get "/v2/services?q=active:f", {}, headers
          last_response.should be_ok
          decoded_guids.should =~ @inactive.map(&:guid)
        end
      end

      describe 'filtering by label' do
        let(:my_service) { @active.fetch(0) }

        before do
          my_service.label = 'my-service'
          my_service.save
        end

        it 'includes only matching services in the response' do
          get '/v2/services?q=label:my-service', {}, headers
          last_response.should be_ok
          decoded_guids.should == [my_service.guid]
        end
      end

      describe 'filtering by provider' do
        context 'for a v1 service' do
          let(:my_service) { @active.fetch(0) }

          before do
            my_service.provider = 'my-provider'
            my_service.save
          end

          it 'includes only matching services in the response' do
            get '/v2/services?q=provider:my-provider', {}, headers
            last_response.should be_ok
            decoded_guids.should == [my_service.guid]
          end
        end

        context 'for a v2 service' do
          let!(:my_service) do
            Service.make(:v2).tap do |service|
              ServicePlan.make(service: service)
            end
          end

          it 'matches when provider is blank' do
            get '/v2/services?q=provider:', {}, headers
            last_response.should be_ok
            decoded_guids.should == [my_service.guid]
          end
        end
      end
    end

    describe 'POST /v2/services' do
      it 'creates a service' do
        unique_id = Sham.unique_id
        url = Sham.url
        documentation_url = Sham.url
        long_description = Sham.long_description

        payload = ServicesController::CreateMessage.new(
          :unique_id => unique_id,
          :url => url,
          :documentation_url => documentation_url,
          :description => 'delightful service',
          :long_description => long_description,
          :provider => 'widgets-inc',
          :label => 'foo-db',
          :version => 'v1.2.3'
        ).encode

        expect {
          post '/v2/services', payload, json_headers(admin_headers)
        }.to change(Service, :count).by(1)

        last_response.status.should eq(201)
        guid = decoded_response.fetch('metadata').fetch('guid')

        service = Service.last
        expect(service.guid).to eq(guid)
        expect(service.unique_id).to eq(unique_id)
        expect(service.url).to eq(url)
        expect(service.documentation_url).to eq(documentation_url)
        expect(service.description).to eq('delightful service')
        expect(service.long_description).to eq(long_description)
        expect(service.provider).to eq('widgets-inc')
        expect(service.label).to eq('foo-db')
        expect(service.version).to eq('v1.2.3')
      end

      it 'makes the service bindable by default' do
        payload_without_bindable = ServicesController::CreateMessage.new(
          :label => Sham.label,
          :provider => Sham.provider,
          :url => Sham.url,
          :description => 'd',
          :version => 'v',
          :unique_id => Sham.unique_id,
        ).encode
        post "/v2/services", payload_without_bindable, json_headers(admin_headers)
        last_response.status.should eq(201)
        service_guid = decoded_response.fetch('metadata').fetch('guid')
        Service.first(:guid => service_guid).bindable.should be_true
      end

      it 'creates the service with default tags' do
        payload_without_tags = ServicesController::CreateMessage.new(
          :label => Sham.label,
          :provider => Sham.provider,
          :url => Sham.url,
          :description => 'd',
          :version => 'v',
          :unique_id => Sham.unique_id
        ).encode
        post "/v2/services", payload_without_tags, json_headers(admin_headers)
        last_response.status.should eq(201)
        service_guid = decoded_response.fetch('metadata').fetch('guid')
        Service.first(:guid => service_guid).tags.should == []
      end

      it 'creates the service with specified tags' do
        payload_with_tags = ServicesController::CreateMessage.new(
          :label => Sham.label,
          :provider => Sham.provider,
          :url => Sham.url,
          :description => 'd',
          :version => 'v',
          :unique_id => Sham.unique_id,
          :tags => ["relational"]
        ).encode
        post "/v2/services", payload_with_tags, json_headers(admin_headers)
        last_response.status.should eq(201)
        service_guid = decoded_response.fetch('metadata').fetch('guid')
        Service.first(:guid => service_guid).tags.should == ["relational"]
      end

      it 'creates the service with default requires' do
        payload_without_requires = ServicesController::CreateMessage.new(
          :label => Sham.label,
          :provider => Sham.provider,
          :url => Sham.url,
          :description => 'd',
          :version => 'v',
          :unique_id => Sham.unique_id
        ).encode
        post "/v2/services", payload_without_requires, json_headers(admin_headers)
        last_response.status.should eq(201)
        service_guid = decoded_response.fetch('metadata').fetch('guid')
        Service.first(:guid => service_guid).requires.should == []
      end

      it 'creates the service with specified requires' do
        payload_with_requires = ServicesController::CreateMessage.new(
          :label => Sham.label,
          :provider => Sham.provider,
          :url => Sham.url,
          :description => 'd',
          :version => 'v',
          :unique_id => Sham.unique_id,
          :requires => ["loggyness"]
        ).encode
        post "/v2/services", payload_with_requires, json_headers(admin_headers)
        last_response.status.should eq(201)
        service_guid = decoded_response.fetch('metadata').fetch('guid')
        Service.first(:guid => service_guid).requires.should == ["loggyness"]
      end
    end

    describe 'PUT /v2/services/:guid' do
      let!(:service) { Service.make }

      context "when updating the unique_id attribute" do
        it "is successful" do
          new_unique_id = service.unique_id.reverse
          payload = Yajl::Encoder.encode({"unique_id" => new_unique_id})

          put "/v2/services/#{service.guid}", payload, json_headers(admin_headers)

          service.reload
          expect(last_response.status).to be == 201
          expect(service.unique_id).to be == new_unique_id
        end

        context "when the given unique_id is taken" do
          let!(:other_service) { Service.make }

          it "gives the correct error response" do
            payload = Yajl::Encoder.encode({"unique_id" => other_service.unique_id})
            put "/v2/services/#{service.guid}", payload, json_headers(admin_headers)
            expect(last_response.status).to be == 400
            expect(decoded_response).to have_key('backtrace')
            expect(decoded_response.fetch('code')).to eql(120001)
            expect(decoded_response.fetch('error_code')).to eql('CF-ServiceInvalid')
            expect(decoded_response.fetch('types')).to eql(%w(ServiceInvalid Error))
            expect(decoded_response.fetch('description')).to eql('The service is invalid: Service ids must be unique')
          end
        end
      end

      context 'when providing an invalid url attribute' do
        before do
          put "/v2/services/#{service.guid}", Yajl::Encoder.encode({ url: 'banana' }), json_headers(admin_headers)
        end

        it "should return a 400" do
          last_response.status.should == 400
        end

        it "should not return a location header" do
          last_response.location.should be_nil
        end

        it "should return the request guid in the header" do
          last_response.headers["X-VCAP-Request-ID"].should_not be_nil
        end

        it_behaves_like "a vcap rest error response", /must be a valid URL/
      end
    end

    describe 'DELETE /v2/services/:guid' do
      context 'when the purge parameter is "true"'
      let!(:service) { Service.make(:v2) }
      let!(:service_plan) { ServicePlan.make(service: service) }
      let!(:service_instance) { ManagedServiceInstance.make(service_plan: service_plan) }
      let!(:service_binding) { ServiceBinding.make(service_instance: service_instance) }

      before do
        stub_request(:delete, /#{service.service_broker.broker_url}.*/).to_return(body: {}, code: 200)
      end

      it 'deletes the service and its dependent models' do
        delete "/v2/services/#{service.guid}?purge=true", '{}', json_headers(admin_headers)

        expect(last_response.status).to eq(204)
        expect(Service.first(guid: service.guid)).to be_nil
        expect(ServicePlan.first(guid: service_plan.guid)).to be_nil
        expect(ServiceInstance.first(guid: service_instance.guid)).to be_nil
      end

      it 'does not contact the broker' do
        delete "/v2/services/#{service.guid}?purge=true", '{}', json_headers(admin_headers)

        expect(a_request(:delete, /#{service.service_broker.broker_url}.*/)).not_to have_been_made
      end
    end
  end
end
