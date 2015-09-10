require 'spec_helper'

module VCAP::CloudController
  describe PrivateDomainsController do
    describe 'Query Parameters' do
      it { expect(described_class).to be_queryable_by(:name) }
    end

    describe 'Attributes' do
      it do
        expect(described_class).to have_creatable_attributes({
          name: { type: 'string', required: true },
          owning_organization_guid: { type: 'string', required: true }
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          name: { type: 'string' },
          owning_organization_guid: { type: 'string' }
        })
      end
    end

    describe 'Creating' do
      context 'as an org manager' do
        let(:user) { User.make }
        let(:organization) { Organization.make }

        let(:request_body) do
          MultiJson.dump({ name: 'blah.com', owning_organization_guid: organization.guid })
        end

        before do
          organization.add_user(user)
          organization.add_manager(user)
        end

        context 'when domain_creation feature_flag is disabled' do
          before do
            FeatureFlag.make(name: 'private_domain_creation', enabled: false, error_message: nil)
          end

          it 'returns FeatureDisabled' do
            post '/v2/private_domains', request_body, headers_for(user)

            expect(last_response.status).to eq(403)
            expect(decoded_response['error_code']).to match(/FeatureDisabled/)
            expect(decoded_response['description']).to match(/private_domain_creation/)
          end
        end
      end
    end

    describe 'Associations' do
      it do
        expect(described_class).to have_nested_routes(
          {
            shared_organizations: [:get],
          })
      end

      describe 'shared organizations associations' do
        let(:private_domain) { PrivateDomain.make }

        before do
          Organization.make.add_private_domain(private_domain)
        end

        it 'returns links for shared organizations' do
          get "/v2/private_domains/#{private_domain.guid}?inline-relations-depth=1", {}, json_headers(admin_headers)

          expect(entity).to have_key('shared_organizations_url')
          expect(entity).to_not have_key('shared_organizations')
        end
      end
    end

    describe 'Validation messages' do
      let(:organization) { Organization.make }

      it 'returns the OrgQuotaTotalPrivateDomainExceed message' do
        quota_definition = organization.quota_definition
        quota_definition.total_private_domains = 0
        quota_definition.save

        post '/v2/private_domains', MultiJson.dump(name: 'foo.com', owning_organization_guid: organization.guid), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(130005)
        expect(decoded_response['description']).to include(organization.name)
      end
    end
  end
end
