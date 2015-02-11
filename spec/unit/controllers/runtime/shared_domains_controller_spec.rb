require 'spec_helper'

module VCAP::CloudController
  describe SharedDomainsController do
    describe 'Query Parameters' do
      it { expect(described_class).to be_queryable_by(:name) }
    end

    describe 'Attributes' do
      it do
        expect(described_class).to have_creatable_attributes({
          name: { type: 'string', required: true }
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          name: { type: 'string' }
        })
      end
    end

    describe 'audit events' do
      it 'logs audit.domain.delete-request when deleting a domain' do
        domain = SharedDomain.make
        domain_guid = domain.guid
        delete "/v2/shared_domains/#{domain_guid}", '', json_headers(admin_headers)

        expect(last_response.status).to eq(204)

        event = Event.find(type: 'audit.domain.delete-request', actee: domain_guid)
        expect(event).not_to be_nil
        expect(event.actee).to eq(domain_guid)
        expect(event.actee_name).to eq(domain.name)
        expect(event.organization_guid).to eq('')
        expect(event.actor_name).to eq(SecurityContext.current_user_email)
      end
    end
  end
end
