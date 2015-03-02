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

    describe 'audit events' do
      it 'logs audit.domain.delete-request when deleting a domain' do
        domain = PrivateDomain.make
        domain_guid = domain.guid
        delete "/v2/private_domains/#{domain_guid}", '', json_headers(admin_headers)

        expect(last_response.status).to eq(204)

        event = Event.find(type: 'audit.domain.delete-request', actee: domain_guid)
        expect(event).not_to be_nil
        expect(event.organization_guid).to eq(domain.owning_organization_guid)
        expect(event.actor_name).to eq(SecurityContext.current_user_email)
      end
    end
  end
end
