require "spec_helper"

module VCAP::CloudController
  describe ServiceBindingsController, :services do
    # The create_attribute block can't "see" lets and instance variables
    CREDENTIALS = {'foo' => 'bar'}

    let(:broker_client) { double('broker client') }

    before do
      broker_client.stub(:bind) do |binding|
        binding.broker_provided_id = Sham.guid
        binding.credentials = CREDENTIALS
      end
      broker_client.stub(:unbind)
      Service.any_instance.stub(:client).and_return(broker_client)
    end

    it_behaves_like "an authenticated endpoint",
      path: "/v2/service_bindings"

    include_examples "enumerating objects",
      path: "/v2/service_bindings",
      model: ServiceBinding

    include_examples "reading a valid object",
      path: "/v2/service_bindings",
      model: ServiceBinding,
      basic_attributes: %w(app_guid service_instance_guid)

    include_examples "operations on an invalid object",
      path: "/v2/service_bindings"

    include_examples "creating and updating",
      path: "/v2/service_bindings",
      model: ServiceBinding,
      required_attributes: %w(app_guid service_instance_guid),
      unique_attributes: %w(app_guid service_instance_guid),
      db_required_attributes: %w(credentials),
      extra_attributes: {binding_options: ->{Sham.binding_options}},
      create_attribute: lambda { |name, service_binding|
        case name.to_sym
          when :app_guid
            app = AppFactory.make(space: service_binding.space)
            app.guid
          when :service_instance_guid
            service_instance = ManagedServiceInstance.make(space: service_binding.space)
            service_instance.guid
          when :credentials
            CREDENTIALS
        end
      },
      create_attribute_reset: lambda { @space = nil }

    describe "staging" do
      let(:app_obj) do
        app = AppFactory.make
        app.state = "STARTED"
        app.instances = 1
        fake_app_staging(app)
        app
      end
      let(:service_instance) { ManagedServiceInstance.make(:space => app_obj.space) }

      it "does not flag app for restaging when creating a binding" do
        req = Yajl::Encoder.encode(:app_guid => app_obj.guid,
                                   :service_instance_guid => service_instance.guid)

        post "/v2/service_bindings", req, json_headers(admin_headers)
        last_response.status.should == 201
        app_obj.refresh
        app_obj.needs_staging?.should be_false
      end

      it " does not flag app for restaging when deleting a binding" do
        binding = ServiceBinding.make(:app => app_obj, :service_instance => service_instance)
        fake_app_staging(app_obj)
        app_obj.service_bindings.should include(binding)

        delete "/v2/service_bindings/#{binding.guid}", {}, admin_headers

        last_response.status.should == 204
        app_obj.refresh
        app_obj.needs_staging?.should be_false
      end
    end

    describe "Permissions" do
      include_context "permissions"

      before do
        @app_a = AppFactory.make(:space => @space_a)
        @service_instance_a = ManagedServiceInstance.make(:space => @space_a)
        @obj_a = ServiceBinding.make(:app => @app_a,
                                             :service_instance => @service_instance_a)

        @app_b = AppFactory.make(:space => @space_b)
        @service_instance_b = ManagedServiceInstance.make(:space => @space_b)
        @obj_b = ServiceBinding.make(:app => @app_b,
                                             :service_instance => @service_instance_b)
      end

      let(:creation_req_for_a) do
        Yajl::Encoder.encode(
          :app_guid => AppFactory.make(:space => @space_a).guid,
          :service_instance_guid => ManagedServiceInstance.make(:space => @space_a).guid
        )
      end

      let(:update_req_for_a) do
        Yajl::Encoder.encode({})
      end

      describe "Org Level Permissions" do
        describe "OrgManager" do
          let(:member_a) { @org_a_manager }
          let(:member_b) { @org_b_manager }

          include_examples "permission enumeration", "OrgManager",
            :name => 'service binding',
            :path => "/v2/service_bindings",
            :enumerate => 0
        end

        describe "OrgUser" do
          let(:member_a) { @org_a_member }
          let(:member_b) { @org_b_member }

          include_examples "permission enumeration", "OrgUser",
            :name => 'service binding',
            :path => "/v2/service_bindings",
            :enumerate => 0
        end

        describe "BillingManager" do
          let(:member_a) { @org_a_billing_manager }
          let(:member_b) { @org_b_billing_manager }

          include_examples "permission enumeration", "BillingManager",
            :name => 'service binding',
            :path => "/v2/service_bindings",
            :enumerate => 0
        end

        describe "Auditor" do
          let(:member_a) { @org_a_auditor }
          let(:member_b) { @org_b_auditor }

          include_examples "permission enumeration", "Auditor",
            :name => 'service binding',
            :path => "/v2/service_bindings",
            :enumerate => 0
        end
      end

      describe "App Space Level Permissions" do
        describe "SpaceManager" do
          let(:member_a) { @space_a_manager }
          let(:member_b) { @space_b_manager }

          include_examples "permission enumeration", "SpaceManager",
            :name => 'service binding',
            :path => "/v2/service_bindings",
            :enumerate => 0
        end

        describe "Developer" do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }

          include_examples "permission enumeration", "Developer",
            :name => 'service binding',
            :path => "/v2/service_bindings",
            :enumerate => 1
        end

        describe "SpaceAuditor" do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }

          include_examples "permission enumeration", "SpaceAuditor",
            :name => 'service binding',
            :path => "/v2/service_bindings",
            :enumerate => 1
        end
      end
    end

    describe 'for provided instances' do
      let(:space) { Space.make }
      let(:developer) { make_developer_for_space(space) }
      let(:application) { AppFactory.make(:space => space) }
      let(:service_instance) { UserProvidedServiceInstance.make(:space => space) }
      let(:params) do
        {
          "app_guid" => application.guid,
          "service_instance_guid" => service_instance.guid
        }
      end

      it 'creates a service binding' do
        post "/v2/service_bindings", params.to_json, headers_for(developer)
        last_response.status.should == 201
      end

      it 'honors the binding options' do
        binding_options = Sham.binding_options
        body =  params.merge("binding_options" => binding_options).to_json
        post "/v2/service_bindings", body, headers_for(developer)
        ServiceBinding.last.binding_options.should == binding_options
      end
    end

    describe 'POST', '/v2/service_bindings' do
      let(:instance) { ManagedServiceInstance.make }
      let(:space) { instance.space }
      let(:plan) { instance.service_plan }
      let(:service) { plan.service }
      let(:developer) { make_developer_for_space(space) }
      let(:app_obj) { AppFactory.make(space: space) }

      it 'binds a service instance to an app' do
        req = {
          :app_guid => app_obj.guid,
          :service_instance_guid => instance.guid
        }.to_json

        post "/v2/service_bindings", req, json_headers(headers_for(developer))
        expect(last_response.status).to eq(201)

        expect(broker_client).to have_received(:bind)

        binding = ServiceBinding.last
        expect(binding.credentials).to eq(CREDENTIALS)
      end

      it 'unbinds the service instance when an exception is raised' do
        req = Yajl::Encoder.encode(
          :app_guid => app_obj.guid,
          :service_instance_guid => instance.guid
        )

        ServiceBinding.any_instance.stub(:save).and_raise

        post "/v2/service_bindings", req, json_headers(headers_for(developer))
        expect(broker_client).to have_received(:unbind).with(an_instance_of(ServiceBinding))
        expect(last_response.status).to eq(500)
      end

      context 'when attempting to bind to an unbindable service' do
        before do
          service.bindable = false
          service.save

          req = {
            :app_guid => app_obj.guid,
            :service_instance_guid => instance.guid
          }.to_json

          post "/v2/service_bindings", req, json_headers(headers_for(developer))
        end

        it 'raises UnbindableService error' do
          hash_body = JSON.parse(last_response.body)
          expect(hash_body['error_code']).to eq('CF-UnbindableService')
          expect(last_response.status).to eq(400)
        end

        it 'does not send a bind request to broker' do
          expect(broker_client).to_not have_received(:bind)
        end

      end

      context 'when the app is invalid' do
        context 'because app_guid is invalid' do
          let(:req) do
            {
              app_guid: 'THISISWRONG',
              service_instance_guid: instance.guid
            }.to_json
          end

          before do
            service.save
          end

          it 'returns CF-AppNotFound' do
            post '/v2/service_bindings', req, json_headers(headers_for(developer))

            hash_body = JSON.parse(last_response.body)
            expect(hash_body['error_code']).to eq('CF-AppNotFound')
            expect(last_response.status).to eq(404)
          end
        end

        context 'because the app is destroyed after controller validation and before binding save' do
          let(:req) do
            {
              app_guid: 'THISISWRONG',
              service_instance_guid: instance.guid
            }.to_json
          end

          before do
            service.save
            allow_any_instance_of(ServiceBindingsController).to receive(:validate_access).and_return(true)
            allow_any_instance_of(ServiceBindingsController).to receive(:validate_app).and_return(true)
          end

          it 'returns CF-AppNotFound' do
            post '/v2/service_bindings', req, json_headers(headers_for(developer))

            hash_body = JSON.parse(last_response.body)
            expect(hash_body['error_code']).to eq('CF-AppNotFound')
            expect(last_response.status).to eq(404)
          end
        end
      end

      context 'when the service instance is invalid' do
        context 'because service_instance_guid is invalid' do
          let(:req) do
            {
              app_guid: app_obj.guid,
              service_instance_guid: 'THISISWRONG'
            }.to_json
          end

          before do
            service.save
          end

          it 'returns CF-ServiceInstanceNotFound error' do
            post '/v2/service_bindings', req, json_headers(headers_for(developer))

            hash_body = JSON.parse(last_response.body)
            expect(hash_body['error_code']).to eq('CF-ServiceInstanceNotFound')
            expect(last_response.status).to eq(404)
          end
        end

        context 'because the service instance is destroyed after controller validation and before binding save' do
          let(:req) do
            {
              app_guid: app_obj.guid,
              service_instance_guid: 'THISISWRONG'
            }.to_json
          end

          before do
            service.save

            allow(broker_client).to receive(:bind).and_return(true)
            allow_any_instance_of(ServiceBinding).to receive(:client).and_return(broker_client)
            allow_any_instance_of(ServiceBindingsController).to receive(:validate_access).and_return(true)
            allow_any_instance_of(ServiceBindingsController).to receive(:validate_service_instance).and_return(true)
          end

          it 'returns CF-ServiceInstanceNotFound error' do
            post '/v2/service_bindings', req, json_headers(headers_for(developer))

            hash_body = JSON.parse(last_response.body)
            expect(hash_body['error_code']).to eq('CF-ServiceInstanceNotFound')
            expect(last_response.status).to eq(404)
          end
        end
      end

      describe 'binding errors' do
        subject(:make_request) do
          req = {
            app_guid: app_obj.guid,
            service_instance_guid: instance.guid
          }.to_json
          post "/v2/service_bindings", req, json_headers(headers_for(developer))
        end

        context 'when attempting to bind and the service binding already exists' do
          before do
            ServiceBinding.make(:app => app_obj, :service_instance => instance)
          end

          it 'returns a 400' do
            make_request
            expect(last_response.status).to eq(400)
          end

          it 'returns a ServiceBindingAppServiceTaken error' do
            make_request
            expect(decoded_response['error_code']).to eq('CF-ServiceBindingAppServiceTaken')
          end

          it 'does not send a bind request to broker' do
            make_request
            expect(broker_client).not_to have_received(:bind)
          end
        end

        context 'when the v2 broker returns a 409' do
          before do
            service.service_broker = ServiceBroker.make
            broker_client.stub(:bind) do
              uri = 'http://broker.url.com'
              method = 'PUT'
              response = double(:response, code: 409, body: '{}')
              raise VCAP::Services::ServiceBrokers::V2::ServiceBrokerConflict.new(uri, method, response)
            end
          end

          it 'returns a 409' do
            make_request
            expect(last_response.status).to eq 409
          end

          it 'returns a ServiceBindingAppServiceTaken error' do
            make_request
            expect(decoded_response['error_code']).to eq 'CF-ServiceBrokerConflict'
          end
        end

        context 'when the v2 broker returns any other error' do
          before do
            service.service_broker = ServiceBroker.make
            broker_client.stub(:bind) do
              uri = 'http://broker.url.com'
              method = 'PUT'
              response = double(:response, code: 500, body: '{"description": "ERROR MESSAGE HERE"}')
              raise VCAP::Services::ServiceBrokers::V2::ServiceBrokerBadResponse.new(uri, method, response)
            end
          end

          it 'returns a 500' do
            make_request
            expect(last_response.status).to eq 500
          end

          it 'passes through the error message' do
            make_request
            expect(decoded_response['description']).to match /ERROR MESSAGE HERE/
          end
        end
      end
    end

    describe 'DELETE', '/v2/service_bindings/:service_binding_guid' do
      let(:binding) { ServiceBinding.make }
      let(:developer) { make_developer_for_space(binding.service_instance.space) }

      it 'returns 204' do
        delete "/v2/service_bindings/#{binding.guid}", '', json_headers(headers_for(developer))
        expect(last_response.status).to eq 204
      end

      it 'returns an empty response body' do
        delete "/v2/service_bindings/#{binding.guid}", '', json_headers(headers_for(developer))
        expect(last_response.body).to be_empty
      end

      it 'unbinds a service instance from an app' do
        delete "/v2/service_bindings/#{binding.guid}", '', json_headers(headers_for(developer))
        expect(ServiceBinding.find(guid: binding.guid)).to be_nil
        expect(broker_client).to have_received(:unbind).with(binding)
      end
    end

    describe 'GET', '/v2/service_bindings?inline-relations-depth=1', regression: true do
      it 'returns both user provided and managed service instances' do
        managed_service_instance = ManagedServiceInstance.make
        managed_binding = ServiceBinding.make(service_instance: managed_service_instance)

        user_provided_service_instance = UserProvidedServiceInstance.make
        user_provided_binding = ServiceBinding.make(service_instance: user_provided_service_instance)

        get "/v2/service_bindings?inline-relations-depth=1", {}, admin_headers
        expect(last_response.status).to eql(200)

        service_bindings = decoded_response["resources"]
        service_instance_guids = service_bindings.map do |res|
          res["entity"]["service_instance"]["metadata"]["guid"]
        end

        expect(service_instance_guids).to match_array([
          managed_service_instance.guid,
          user_provided_service_instance.guid,
        ])
      end
    end
  end
end
