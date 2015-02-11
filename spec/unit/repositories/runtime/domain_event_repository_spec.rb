require 'spec_helper'

module VCAP::CloudController
  module Repositories::Runtime
    describe DomainEventRepository do
      let(:user) { User.make }
      let(:organization) { Organization.make }
      let(:domain) { Domain.make(owning_organization: organization) }
      let(:user_email) { 'email address' }

      subject(:domain_event_repository) { DomainEventRepository.new }

      describe '#record_domain_delete' do
        it 'records event correctly' do
          event = domain_event_repository.record_domain_delete_request(domain, user, user_email)
          event.reload
          expect(event.type).to eq('audit.domain.delete-request')
          expect(event.actee).to eq(domain.guid)
          expect(event.actee_type).to eq('domain')
          expect(event.actee_name).to eq(domain.name)
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.organization_guid).to eq(domain.owning_organization.guid)
        end
      end
    end
  end
end
