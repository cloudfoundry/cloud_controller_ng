require 'spec_helper'

module VCAP::CloudController
  describe ServicesController, :services do
    shared_examples 'enumerate and read service only' do |perm_name|
      include_examples 'permission enumeration', perm_name,
                       name: 'service',
                       path: '/v2/services',
                       permissions_overlap: true,
                       enumerate: 7
    end

    describe 'Query Parameters' do
      it { expect(described_class).to be_queryable_by(:active) }
      it { expect(described_class).to be_queryable_by(:label) }
      it { expect(described_class).to be_queryable_by(:provider) }
      it { expect(described_class).to be_queryable_by(:service_broker_guid) }
    end

    describe 'Attributes' do
      it do
        expect(described_class).to have_creatable_attributes({
          label:              { type: 'string', required: true },
          description:        { type: 'string', required: true },
          long_description:   { type: 'string' },
          info_url:           { type: 'string /url_regex/' },
          documentation_url:  { type: 'string /url_regex/' },
          acls:               { type: '{"users" => [string], "wildcards" => [string]}' },
          timeout:            { type: 'integer' },
          active:             { type: 'bool', default: false },
          bindable:           { type: 'bool', default: true },
          extra:              { type: 'string' },
          unique_id:          { type: 'string' },
          tags:               { type: '[string]', default: [] },
          requires:           { type: '[string]', default: [] },
          provider:           { type: 'string', required: true },
          version:            { type: 'string', required: true },
          url:                { type: 'string /url_regex/', required: true },
          service_plan_guids: { type: '[string]' }
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          label:              { type: 'string' },
          description:        { type: 'string' },
          long_description:   { type: 'string' },
          info_url:           { type: 'string /url_regex/' },
          documentation_url:  { type: 'string /url_regex/' },
          acls:               { type: '{"users" => [string], "wildcards" => [string]}' },
          timeout:            { type: 'integer' },
          active:             { type: 'bool' },
          bindable:           { type: 'bool' },
          extra:              { type: 'string' },
          unique_id:          { type: 'string' },
          tags:               { type: '[string]' },
          requires:           { type: '[string]' },
          provider:           { type: 'string' },
          version:            { type: 'string' },
          url:                { type: 'string /url_regex/' },
          service_plan_guids: { type: '[string]' }
        })
      end
    end

    describe 'Associations' do
      it do
        expect(described_class).to have_nested_routes({ service_plans: [:get, :put, :delete] })
      end
    end

    describe 'Permissions' do
      include_context 'permissions'

      before do
        5.times { ServicePlan.make }
        @obj_a = ServicePlan.make.service
        @obj_b = ServicePlan.make.service
      end

      describe 'Org Level Permissions' do
        describe 'OrgManager' do
          let(:member_a) { @org_a_manager }
          let(:member_b) { @org_b_manager }

          include_examples 'enumerate and read service only', 'OrgManager'
        end

        describe 'OrgUser' do
          let(:member_a) { @org_a_member }
          let(:member_b) { @org_b_member }

          include_examples 'enumerate and read service only', 'OrgUser'
        end

        describe 'BillingManager' do
          let(:member_a) { @org_a_billing_manager }
          let(:member_b) { @org_b_billing_manager }

          include_examples 'enumerate and read service only', 'BillingManager'
        end

        describe 'Auditor' do
          let(:member_a) { @org_a_auditor }
          let(:member_b) { @org_b_auditor }

          include_examples 'enumerate and read service only', 'Auditor'
        end
      end

      describe 'App Space Level Permissions' do
        describe 'SpaceManager' do
          let(:member_a) { @space_a_manager }
          let(:member_b) { @space_b_manager }

          include_examples 'enumerate and read service only', 'SpaceManager'
        end

        describe 'Developer' do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }

          include_examples 'enumerate and read service only', 'Developer'
        end

        describe 'SpaceAuditor' do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }

          include_examples 'enumerate and read service only', 'SpaceAuditor'
        end
      end
    end

    describe 'GET /v2/services' do
      let(:organization) do
        Organization.make.tap do |org|
          org.add_user(user)
          org.add_manager(user)
          org.add_billing_manager(user)
          org.add_auditor(user)
        end
      end

      let(:user) { VCAP::CloudController::User.make }
      let(:headers) { headers_for(user) }
      let(:service_broker) { ServiceBroker.make(name: 'FreeWidgets') }

      let!(:public_and_active) do
        opts = { active: true, long_description: Sham.long_description, service_broker: service_broker }
        Service.make(opts).tap do |svc|
          ServicePlan.make(public: true, active: true, service: svc)
        end
      end

      let!(:public_and_inactive) do
        opts = { active: false, long_description: Sham.long_description, service_broker: service_broker }
        Service.make(opts).tap do |svc|
          ServicePlan.make(public: true, active: false, service: svc)
        end
      end

      let!(:private_and_active) do
        opts = { active: true, long_description: Sham.long_description, service_broker: service_broker }
        Service.make(opts).tap do |svc|
          ServicePlan.make(public: false, active: true, service: svc)
        end
      end

      let!(:private_and_inactive) do
        opts = { active: false, long_description: Sham.long_description, service_broker: service_broker }
        Service.make(opts).tap do |svc|
          ServicePlan.make(public: false, active: false, service: svc)
        end
      end

      let!(:private_with_visibility_to_user) do
        opts = { active: true, long_description: Sham.long_description, service_broker: service_broker }
        Service.make(opts).tap do |svc|
          plan = ServicePlan.make(public: false, active: true, service: svc)
          ServicePlanVisibility.make(service_plan: plan, organization: organization)
        end
      end

      def visible_services
        [public_and_active, private_with_visibility_to_user]
      end

      def active_services
        [public_and_active, private_and_active, private_with_visibility_to_user]
      end

      def inactive_services
        [public_and_inactive, private_and_inactive]
      end

      def decoded_guids
        decoded_response['resources'].map { |r| r['metadata']['guid'] }
      end

      def decoded_long_descriptions
        decoded_response['resources'].map { |r| r['entity']['long_description'] }
      end

      it 'returns plans visible to the user' do
        get '/v2/services', {}, headers
        expect(last_response.status).to eq 200
        expect(decoded_guids).to eq(visible_services.map(&:guid))
      end

      context 'when the user has an invalid auth token' do
        let(:headers) do
          {
            'HTTP_AUTHORIZATION' => "bearer #{SecureRandom.uuid}"
          }
        end

        it 'raises an InvalidAuthToken error' do
          get '/v2/services', {}, headers
          expect(last_response.status).to eq 401
        end
      end

      context 'when the user has no auth token' do
        let(:headers) { {} }

        it 'does not allow the unauthed user to use inline-relations-depth' do
          get '/v2/services?inline-relations-depth=1', {}, headers
          services = decoded_response.fetch('resources').map { |service| service['entity'] }
          services.each do |service|
            expect(service['service_plans']).to be_nil
          end
        end
      end
    end

    describe 'DELETE /v2/services/:guid' do
      let(:email) { 'admin@example.com' }

      let!(:service) { Service.make(:v2) }
      let!(:service_plan) { ServicePlan.make(service: service) }
      let!(:service_instance) { ManagedServiceInstance.make(service_plan: service_plan) }
      let!(:service_binding) { ServiceBinding.make(service_instance: service_instance) }
      let!(:service_key) { ServiceKey.make(service_instance: service_instance) }

      context 'when no purge parameter is given' do
        it 'gives error info to user' do
          delete "/v2/services/#{service.guid}", '{}', headers_for(admin_user, email: email)

          expect(last_response).to have_status_code 400
          expect(last_response.body).to match /AssociationNotEmpty/
        end
      end

      context 'when the purge parameter is "true"' do
        before do
          stub_request(:delete, /#{service.service_broker.broker_url}.*/).to_return(body: '', status: 200)
        end

        it 'creates a service delete event' do
          delete "/v2/services/#{service.guid}?purge=true", '{}', headers_for(admin_user, email: email)
          expect(last_response.status).to eq(204)

          event = Event.all.last
          expect(event.type).to eq('audit.service.delete')
          expect(event.actor_type).to eq('user')
          expect(event.timestamp).to be
          expect(event.actor).to eq(admin_user.guid)
          expect(event.actor_name).to eq(email)
          expect(event.actee).to eq(service.guid)
          expect(event.actee_type).to eq('service')
          expect(event.actee_name).to eq(service.label)
          expect(event.space_guid).to be_empty
          expect(event.organization_guid).to be_empty
          expect(event.metadata).to include({
            'request' => {
              'purge' => true,
            }
          })
        end

        it 'requires authentication' do
          delete "/v2/services/#{service.guid}", '{}', headers_for(nil)
          expect(last_response.status).to eq 401
        end

        it 'deletes the service and its dependent models' do
          delete "/v2/services/#{service.guid}?purge=true", '{}', json_headers(admin_headers)

          expect(last_response).to have_status_code(204)
          expect(Service.first(guid: service.guid)).to be_nil
          expect(ServicePlan.first(guid: service_plan.guid)).to be_nil
          expect(ServiceInstance.first(guid: service_instance.guid)).to be_nil
          expect(ServiceBinding.first(guid: service_binding.guid)).to be_nil
          expect(ServiceKey.first(guid: service_key.guid)).to be_nil
        end

        it 'does not contact the broker' do
          delete "/v2/services/#{service.guid}?purge=true", '{}', json_headers(admin_headers)

          expect(a_request(:delete, /#{service.service_broker.broker_url}.*/)).not_to have_been_made
        end
      end
    end
  end
end
