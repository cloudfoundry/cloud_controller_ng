require 'spec_helper'
require 'decorators/field_include_service_instance_space_organization_decorator'

module VCAP::CloudController
  RSpec.describe FieldIncludeServiceInstanceSpaceOrganizationDecorator do
    describe '.decorate' do
      let(:org1) { Organization.make }
      let(:org2) { Organization.make }

      let(:space1) { Space.make(organization: org1) }
      let(:space2) { Space.make(organization: org2) }

      let!(:service_instance_1) { ManagedServiceInstance.make(space: space1) }
      let!(:service_instance_2) { UserProvidedServiceInstance.make(space: space2) }

      it 'decorated the given hash with spaces and orgs from service instances' do
        undecorated_hash = { foo: 'bar', included: { monkeys: %w(zach greg) } }
        hash = described_class.decorate(undecorated_hash, [service_instance_1, service_instance_2])

        expect(hash).to match({
          foo: 'bar',
          included: {
            monkeys: %w(zach greg),
            spaces: [
              {
                name: space1.name,
                guid: space1.guid,
                relationships: {
                  organization: {
                    data: {
                      guid: org1.guid
                    }
                  }
                }
              },
              {
                name: space2.name,
                guid: space2.guid,
                relationships: {
                  organization: {
                    data: {
                      guid: org2.guid
                    }
                  }
                }
              }
            ],
            organizations: [
              {
                name: org1.name,
                guid: org1.guid
              },
              {
                name: org2.name,
                guid: org2.guid
              }
            ]
          }
        })
      end

      context 'when instances share a space' do
        let!(:service_instance_3) { ManagedServiceInstance.make(space: space1) }

        it 'does not duplicate the space' do
          hash = described_class.decorate({}, [service_instance_1, service_instance_3])
          expect(hash[:included][:spaces]).to have(1).element
        end
      end

      context 'when instances share an org' do
        let(:space3) { Space.make(organization: org1) }
        let!(:service_instance_3) { ManagedServiceInstance.make(space: space3) }

        it 'does not duplicate the org' do
          hash = described_class.decorate({}, [service_instance_1, service_instance_3])
          expect(hash[:included][:organizations]).to have(1).element
        end
      end
    end

    describe '.match?' do
      it 'matches hashes containing key symbol `space.organization` and value `name`' do
        expect(described_class.match?({ 'space.organization': 'name', other: 'bar' })).to be_truthy
      end

      it 'does not match other values' do
        expect(described_class.match?({ 'space.organization': 'foo', other: 'bar' })).to be_falsey
      end

      it 'does not match non-hashes' do
        expect(described_class.match?('foo')).to be_falsey
      end
    end
  end
end
