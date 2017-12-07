require 'spec_helper'
require 'actions/organization_create'

module VCAP::CloudController
  RSpec.describe OrganizationCreate do
    describe 'create' do
      let(:perm_client) { instance_spy(VCAP::CloudController::Perm::Client) }

      it 'creates a organization' do
        message = VCAP::CloudController::OrganizationCreateMessage.new(name: 'my-organization')
        organization = OrganizationCreate.new(perm_client: perm_client).create(message)

        expect(organization.name).to eq('my-organization')
      end

      context 'when a model validation fails' do
        it 'raises an error' do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          expect(VCAP::CloudController::Organization).to receive(:create).
            and_raise(Sequel::ValidationFailed.new(errors))

          message = VCAP::CloudController::OrganizationCreateMessage.new(name: 'foobar')
          expect {
            OrganizationCreate.new(perm_client: perm_client).create(message)
          }.to raise_error(OrganizationCreate::Error, 'blork is busted')
        end

        context 'when it is a uniqueness error' do
          let(:name) { 'Olsen' }

          before do
            VCAP::CloudController::Organization.create(name: name)
          end

          it 'raises a human-friendly error' do
            message = VCAP::CloudController::OrganizationCreateMessage.new(name: name)
            expect {
              OrganizationCreate.new(perm_client: perm_client).create(message)
            }.to raise_error(OrganizationCreate::Error, 'Name must be unique')
          end
        end
      end
    end
  end
end
