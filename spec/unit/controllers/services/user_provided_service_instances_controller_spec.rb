require 'spec_helper'

module VCAP::CloudController
  describe UserProvidedServiceInstancesController, :services do
    describe 'Attributes' do
      it do
        expect(described_class).to have_creatable_attributes({
          name:                  { type: 'string', required: true },
          credentials:           { type: 'hash', default: {} },
          syslog_drain_url:      { type: 'string', default: '' },
          space_guid:            { type: 'string', required: true },
          service_binding_guids: { type: '[string]' }
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          name:                  { type: 'string' },
          credentials:           { type: 'hash' },
          syslog_drain_url:      { type: 'string' },
          space_guid:            { type: 'string' },
          service_binding_guids: { type: '[string]' }
        })
      end
    end

    describe 'Permissions' do
      include_context 'permissions'

      before do
        @obj_a = UserProvidedServiceInstance.make(space: @space_a)
        @obj_b = UserProvidedServiceInstance.make(space: @space_b)
      end

      def self.user_sees_empty_enumerate(user_role, member_a_ivar, member_b_ivar)
        describe user_role do
          let(:member_a) { instance_variable_get(member_a_ivar) }
          let(:member_b) { instance_variable_get(member_b_ivar) }

          include_examples 'permission enumeration', user_role,
                           name: 'user provided service instance',
                           path: '/v2/user_provided_service_instances',
                           enumerate: 0
        end
      end

      describe 'Org Level Permissions' do
        user_sees_empty_enumerate('OrgManager',     :@org_a_manager,         :@org_b_manager)
        user_sees_empty_enumerate('OrgUser',        :@org_a_member,          :@org_b_member)
        user_sees_empty_enumerate('BillingManager', :@org_a_billing_manager, :@org_b_billing_manager)
        user_sees_empty_enumerate('Auditor',        :@org_a_auditor,         :@org_b_auditor)
      end

      describe 'App Space Level Permissions' do
        describe 'Developer' do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }

          include_examples 'permission enumeration', 'Developer',
                           name: 'user provided service instance',
                           path: '/v2/user_provided_service_instances',
                           enumerate: 1
        end

        describe 'SpaceAuditor' do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }

          include_examples 'permission enumeration', 'SpaceAuditor',
                           name: 'user provided service instance',
                           path: '/v2/user_provided_service_instances',
                           enumerate: 1
        end

        describe 'SpaceManager' do
          let(:member_a) { @space_a_manager }
          let(:member_b) { @space_b_manager }

          include_examples 'permission enumeration', 'SpaceManager',
            name: 'user provided service instance',
            path: '/v2/user_provided_service_instances',
            enumerate: 1
        end
      end
    end

    describe 'Associations' do
      it do
        expect(described_class).to have_nested_routes({ service_bindings: [:get, :put, :delete] })
      end
    end

    describe 'POST', '/v2/user_provided_service_instances' do
      let(:email) { 'email@example.com' }
      let(:developer) { make_developer_for_space(space) }
      let(:space) { Space.make }
      let(:req) do
        {
          'name' => 'my-upsi',
          'credentials' => { 'uri' => 'https://user:password@service-location.com:port/db' },
          'space_guid' => space.guid
        }
      end

      it 'creates a user provided service instance' do
        post '/v2/user_provided_service_instances', req.to_json, headers_for(developer)

        expect(last_response.status).to eq 201

        service_instance = UserProvidedServiceInstance.first
        expect(service_instance.name).to eq 'my-upsi'
        expect(service_instance.credentials).to eq({ 'uri' => 'https://user:password@service-location.com:port/db' })
        expect(service_instance.space.guid).to eq space.guid
      end

      it 'records a create event' do
        post '/v2/user_provided_service_instances', req.to_json, headers_for(developer, email: email)

        event = Event.first(type: 'audit.user_provided_service_instance.create')
        service_instance = UserProvidedServiceInstance.first

        expect(event.actor).to eq developer.guid
        expect(event.actor_type).to eq 'user'
        expect(event.actor_name).to eq email
        expect(event.actee).to eq service_instance.guid
        expect(event.actee_type).to eq 'user_provided_service_instance'
        expect(event.actee_name).to eq service_instance.name
        expect(event.space_guid).to eq space.guid
        expect(event.metadata).to include({
          'request' => {
            'name' => 'my-upsi',
            'credentials' => '[REDACTED]',
            'space_guid' => space.guid,
            'syslog_drain_url' => ''
          }
        })
      end
    end

    describe 'PUT', '/v2/user_provided_service_instances/:guid' do
      let(:email) { 'email@example.com' }
      let(:developer) { make_developer_for_space(space) }
      let(:space) { Space.make }
      let(:req) do
        {
          'name' => 'my-upsi',
          'credentials' => { 'uri' => 'https://user:password@service-location.com:port/db' }
        }
      end

      let!(:service_instance) { UserProvidedServiceInstance.make(space: space) }

      it 'updates the user provided service instance' do
        put "/v2/user_provided_service_instances/#{service_instance.guid}", req.to_json, headers_for(developer)

        expect(last_response.status).to eq 201

        service_instance = UserProvidedServiceInstance.first
        expect(service_instance.name).to eq 'my-upsi'
        expect(service_instance.credentials).to eq({ 'uri' => 'https://user:password@service-location.com:port/db' })
        expect(service_instance.space.guid).to eq space.guid
      end

      it 'records a update event' do
        put "/v2/user_provided_service_instances/#{service_instance.guid}", req.to_json, headers_for(developer, email: email)

        service_instance = UserProvidedServiceInstance.first
        event = Event.first(type: 'audit.user_provided_service_instance.update')

        expect(event.actor).to eq developer.guid
        expect(event.actor_type).to eq 'user'
        expect(event.actor_name).to eq email
        expect(event.actee).to eq service_instance.guid
        expect(event.actee_type).to eq 'user_provided_service_instance'
        expect(event.actee_name).to eq service_instance.name
        expect(event.space_guid).to eq space.guid
        expect(event.metadata).to include({
          'request' => {
            'name' => 'my-upsi',
            'credentials' => '[REDACTED]'
          }
        })
      end

      describe 'the space_guid parameter' do
        let(:org) { Organization.make }
        let(:space) { Space.make(organization: org) }
        let(:user) { make_developer_for_space(space) }
        let(:instance) { UserProvidedServiceInstance.make(space: space) }

        it 'prevents a developer from moving the service instance to a space for which he is also a space developer' do
          space2 = Space.make(organization: org)
          space2.add_developer(user)

          move_req = MultiJson.dump(
            space_guid: space2.guid,
          )

          put "/v2/user_provided_service_instances/#{instance.guid}", move_req, json_headers(headers_for(user))

          expect(last_response.status).to eq(400)
          expect(decoded_response['description']).to match /cannot change space for service instance/
        end

        it 'succeeds when the space_guid does not change' do
          req = MultiJson.dump(space_guid: instance.space.guid)
          put "/v2/user_provided_service_instances/#{instance.guid}", req, json_headers(headers_for(user))
          expect(last_response.status).to eq 201
        end

        it 'succeeds when the space_guid is not provided' do
          put "/v2/user_provided_service_instances/#{instance.guid}", {}.to_json, json_headers(headers_for(user))
          expect(last_response.status).to eq 201
        end
      end

      context 'when the service instance has a binding' do
        let!(:binding) { ServiceBinding.make service_instance: service_instance }

        it 'propagates the updated credentials to the binding' do
          put "/v2/user_provided_service_instances/#{service_instance.guid}", req.to_json, headers_for(developer)

          expect(binding.reload.credentials).to eq({ 'uri' => 'https://user:password@service-location.com:port/db' })
        end
      end
    end

    describe 'DELETE', '/v2/user_provided_service_instances/:guid' do
      let(:email) { 'email@example.com' }
      let(:developer) { make_developer_for_space(space) }
      let(:space) { Space.make }
      let!(:service_instance) { UserProvidedServiceInstance.make(space: space) }

      it 'deletes the user provided service instance' do
        expect(UserProvidedServiceInstance.all.count).to eq 1
        delete "/v2/user_provided_service_instances/#{service_instance.guid}", {}, headers_for(developer)

        expect(last_response).to have_status_code(204)

        expect(UserProvidedServiceInstance.all.count).to eq 0
      end

      it 'records a create event' do
        service_instance = UserProvidedServiceInstance.first

        delete "/v2/user_provided_service_instances/#{service_instance.guid}", {}, headers_for(developer, email: email)
        event = Event.first(type: 'audit.user_provided_service_instance.delete')
        expect(event.actor).to eq developer.guid
        expect(event.actor_type).to eq 'user'
        expect(event.actor_name).to eq email
        expect(event.actee).to eq service_instance.guid
        expect(event.actee_type).to eq 'user_provided_service_instance'
        expect(event.actee_name).to eq service_instance.name
        expect(event.space_guid).to eq space.guid
        expect(event.metadata).to include({ 'request' => {} })
      end
    end
  end
end
