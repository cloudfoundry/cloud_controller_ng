require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::DomainsController do
    describe 'Query Parameters' do
      it { expect(described_class).to be_queryable_by(:name) }
      it { expect(described_class).to be_queryable_by(:owning_organization_guid) }
    end

    describe 'Attributes' do
      it do
        expect(described_class).to have_creatable_attributes({
          name:                     { type: 'string', required: true },
          wildcard:                 { type: 'bool', default: true },
          owning_organization_guid: { type: 'string' },
          space_guids:              { type: '[string]' }
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          name:                     { type: 'string' },
          wildcard:                 { type: 'bool' },
          owning_organization_guid: { type: 'string' },
          space_guids:              { type: '[string]' }
        })
      end
    end

    describe 'Associations' do
      it do
        expect(described_class).to have_nested_routes({ spaces: [:get, :put, :delete] })
      end
    end

    context 'without seeded domains' do
      before do
        Domain.dataset.destroy # Seeded domains get in the way
      end
    end

    describe 'Permissions' do
      include_context 'permissions'

      before do
        Domain.dataset.destroy # Seeded domains get in the way

        @shared_domain = SharedDomain.make

        @obj_a = PrivateDomain.make(owning_organization: @org_a)

        @obj_b = PrivateDomain.make(owning_organization: @org_b)
      end

      describe 'Org Level Permissions' do
        describe 'OrgManager' do
          let(:member_a) { @org_a_manager }
          let(:member_b) { @org_b_manager }
          let(:enumeration_expectation_a) { [@obj_a, @shared_domain] }

          include_examples 'permission enumeration', 'OrgManager',
            name:      'domain',
            path:      '/v2/domains',
            enumerate: 2
        end

        describe 'OrgUser' do
          let(:member_a) { @org_a_member }
          let(:member_b) { @org_b_member }
          let(:enumeration_expectation_a) { [@shared_domain] }

          include_examples 'permission enumeration', 'OrgUser',
            name:      'domain',
            path:      '/v2/domains',
            enumerate: 1
        end

        describe 'BillingManager' do
          let(:member_a) { @org_a_billing_manager }
          let(:member_b) { @org_b_billing_manager }
          let(:enumeration_expectation_a) { [@shared_domain] }

          include_examples 'permission enumeration', 'BillingManager',
            name:      'domain',
            path:      '/v2/domains',
            enumerate: 1
        end

        describe 'Auditor' do
          let(:member_a) { @org_a_auditor }
          let(:member_b) { @org_b_auditor }
          let(:enumeration_expectation_a) { [@obj_a, @shared_domain] }

          include_examples 'permission enumeration', 'Auditor',
            name:      'domain',
            path:      '/v2/domains',
            enumerate: 2
        end

        context 'with a shared private domain' do
          before do
            @org_b.add_private_domain(@obj_a)
          end

          describe 'OrgManager' do
            let(:member_a) { @org_b_manager }
            let(:enumeration_expectation_a) { [@obj_a, @obj_b, @shared_domain] }

            include_examples 'permission enumeration', 'OrgManager',
              permissions_overlap: true,
              name:      'domain',
              path:      '/v2/domains',
              enumerate: 3
          end

          describe 'SpaceDeveloper' do
            let(:member_a) { @space_b_developer }
            let(:enumeration_expectation_a) { [@obj_a, @obj_b, @shared_domain] }

            include_examples 'permission enumeration', 'SpaceDeveloper',
              permissions_overlap: true,
              name:      'domain',
              path:      '/v2/domains',
              enumerate: 3
          end
        end
      end

      describe 'System Domain permissions' do
        describe 'PUT /v2/domains/:system_domain' do
          it 'does not allow modification of the shared domain by an org manager' do
            set_current_user(@org_a_manager)

            put "/v2/domains/#{@shared_domain.guid}", MultiJson.dump(name: Sham.domain)
            expect(last_response.status).to eq(403)
          end
        end
      end
    end

    it 'is deprecated' do
      get '/v2/domains'
      expect(last_response).to be_a_deprecated_response
    end

    describe 'GET /v2/domains/:id' do
      let(:user) { User.make }
      let(:organization) { Organization.make }

      before { set_current_user(user) }

      context 'a space auditor' do
        let(:space) { Space.make organization: organization }
        let(:domain) { PrivateDomain.make(owning_organization: organization) }

        before do
          organization.add_user user
          space.add_auditor user
        end

        it 'can see the domain' do
          get "/v2/domains/#{domain.guid}"
          expect(last_response.status).to eq 200
          expect(decoded_response['metadata']['guid']).to eq domain.guid
        end
      end

      context 'as an org manager and auditor' do
        before do
          organization.add_user(user)
          organization.add_manager(user)
          organization.add_billing_manager(user)
          organization.add_auditor(user)
        end

        context 'when the domain has an owning organization' do
          let(:domain) { PrivateDomain.make(owning_organization: organization) }

          it 'has its GUID and URL in the response body' do
            get "/v2/domains/#{domain.guid}"

            expect(last_response.status).to eq 200
            expect(decoded_response['entity']['owning_organization_guid']).to eq organization.guid
            expect(decoded_response['entity']['owning_organization_url']).to eq "/v2/organizations/#{organization.guid}"
            expect(last_response).to be_a_deprecated_response
          end
        end

        context 'when the domain is shared' do
          let(:domain) { SharedDomain.make }

          it 'has its GUID as null, and no url key in the response body' do
            get "/v2/domains/#{domain.guid}"

            expect(last_response.status).to eq(200)

            json = MultiJson.load(last_response.body)
            expect(json['entity']['owning_organization_guid']).to be_nil

            expect(json['entity']).not_to include('owning_organization_url')
            expect(last_response).to be_a_deprecated_response
          end
        end
      end
    end

    describe 'GET /v2/domains' do
      let(:user) { User.make }
      let(:space) { VCAP::CloudController::Space.make }
      let(:organization) { space.organization }
      let!(:private_domain) { PrivateDomain.make(owning_organization: organization) }

      context 'for space manager' do
        before do
          space.organization.add_user(user)
          space.add_manager(user)
          set_current_user(user)
        end

        it 'shows private domains for space manager' do
          get '/v2/domains', nil, headers_for(user)

          domains = {}
          parsed_response['resources'].each do |d|
            guid = d['metadata']['guid']
            link = d['metadata']['url']
            domains[guid] = link
          end

          expect(domains[private_domain.guid]).to match /private_domains/
        end
      end

      context 'for space auditor' do
        before do
          space.organization.add_user(user)
          space.add_auditor(user)
          set_current_user(user)
        end

        it 'shows private domains for space auditor' do
          get '/v2/domains', nil, headers_for(user)

          domains = {}
          parsed_response['resources'].each do |d|
            guid = d['metadata']['guid']
            link = d['metadata']['url']
            domains[guid] = link
          end

          expect(domains[private_domain.guid]).to match /private_domains/
        end
      end
    end
    describe 'POST /v2/domains' do
      context 'as an org manager' do
        let(:user) { User.make }
        let(:organization) { Organization.make }

        let(:request_body) do
          MultiJson.dump({ name: 'blah.com', owning_organization_guid: organization.guid })
        end

        before do
          organization.add_user(user)
          organization.add_manager(user)

          set_current_user(user)
        end

        context 'when domain_creation feature_flag is disabled' do
          before do
            FeatureFlag.make(name: 'private_domain_creation', enabled: false, error_message: nil)
          end

          it 'returns FeatureDisabled' do
            post '/v2/domains', request_body

            expect(last_response.status).to eq(403)
            expect(decoded_response['error_code']).to match(/FeatureDisabled/)
            expect(decoded_response['description']).to match(/private_domain_creation/)
          end
        end
      end
    end

    describe 'DELETE /v2/domains/:id' do
      let(:shared_domain) { SharedDomain.make }

      before { set_current_user_as_admin }

      context 'when there are routes using the domain' do
        let!(:route) { Route.make(domain: shared_domain) }

        it 'does not delete the route' do
          expect {
            delete "/v2/domains/#{shared_domain.guid}"
          }.to_not change { SharedDomain.find(guid: shared_domain.guid) }
        end

        it 'returns an error' do
          delete "/v2/domains/#{shared_domain.guid}"
          expect(last_response.status).to eq(400)
          expect(decoded_response['code']).to equal(10006)
          expect(decoded_response['description']).to match /delete the routes associations for your domains/i
        end
      end
    end

    describe 'GET /v2/domains/:id/spaces' do
      let!(:private_domain) { PrivateDomain.make }
      let!(:space) { Space.make(organization: private_domain.owning_organization) }

      before { set_current_user_as_admin }

      it 'returns the spaces associated with the owning organization' do
        get "/v2/domains/#{private_domain.guid}/spaces"
        expect(last_response.status).to eq(200)
        expect(decoded_response['resources']).to have(1).item
        expect(decoded_response['resources'][0]['entity']['name']).to eq(space.name)
        expect(last_response).to be_a_deprecated_response
      end
    end
  end
end
