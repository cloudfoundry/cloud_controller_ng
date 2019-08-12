require 'spec_helper'
require 'actions/organization_create'

module VCAP::CloudController
  RSpec.describe OrganizationCreate do
    describe 'create' do
      let(:perm_client) { instance_spy(VCAP::CloudController::Perm::Client) }

      it 'creates a organization' do
        message = VCAP::CloudController::OrganizationUpdateMessage.new({
          name: 'my-organization',
          metadata: {
            labels: {
              release: 'stable',
              'seriouseats.com/potato' => 'mashed'
            },
            annotations: {
              tomorrow: 'land',
              backstreet: 'boys'
            }
          }
        })
        organization = OrganizationCreate.new(perm_client: perm_client).create(message)

        expect(organization.name).to eq('my-organization')

        expect(organization.labels.map(&:key_name)).to contain_exactly('potato', 'release')
        expect(organization.labels.map(&:key_prefix)).to contain_exactly('seriouseats.com', nil)
        expect(organization.labels.map(&:value)).to contain_exactly('stable', 'mashed')

        expect(organization.annotations.map(&:key)).to contain_exactly('tomorrow', 'backstreet')
        expect(organization.annotations.map(&:value)).to contain_exactly('land', 'boys')
      end

      it 'creates a suspended organization' do
        message = VCAP::CloudController::OrganizationUpdateMessage.new({
          name: 'my-organization',
          suspended: true
        })
        organization = OrganizationCreate.new(perm_client: perm_client).create(message)

        expect(organization.name).to eq('my-organization')
        expect(organization.suspended?).to be true
      end

      context 'when a model validation fails' do
        it 'raises an error' do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          expect(VCAP::CloudController::Organization).to receive(:create).
            and_raise(Sequel::ValidationFailed.new(errors))

          message = VCAP::CloudController::OrganizationUpdateMessage.new(name: 'foobar')
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
            message = VCAP::CloudController::OrganizationUpdateMessage.new(name: name)
            expect {
              OrganizationCreate.new(perm_client: perm_client).create(message)
            }.to raise_error(OrganizationCreate::Error, "Organization '#{name}' already exists.")
          end
        end
      end
    end
  end
end
