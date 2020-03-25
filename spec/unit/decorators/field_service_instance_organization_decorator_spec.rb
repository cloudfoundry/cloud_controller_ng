require 'spec_helper'
require 'decorators/field_service_instance_organization_decorator'

module VCAP::CloudController
  RSpec.describe FieldServiceInstanceOrganizationDecorator do
    describe '.decorate' do
      let(:org1) { Organization.make }
      let(:org2) { Organization.make }

      let(:space1) { Space.make(organization: org1) }
      let(:space2) { Space.make(organization: org2) }

      let!(:service_instance_1) { ManagedServiceInstance.make(space: space1) }
      let!(:service_instance_2) { UserProvidedServiceInstance.make(space: space2) }

      it 'decorated the given hash with orgs names from service instances' do
        undecorated_hash = { foo: 'bar', included: { monkeys: %w(zach greg) } }
        decorator = described_class.new({ 'space.organization': ['name', 'foo'] })

        hash = decorator.decorate(undecorated_hash, [service_instance_1, service_instance_2])

        expect(hash).to match({
          foo: 'bar',
          included: {
            monkeys: %w(zach greg),
            organizations: [
              {
                name: org1.name,
              },
              {
                name: org2.name,
              }
            ]
          }
        })
      end

      it 'decorated the given hash with orgs guids from service instances' do
        undecorated_hash = { foo: 'bar', included: { monkeys: %w(zach greg) } }
        decorator = described_class.new({ 'space.organization': ['guid', 'foo'] })

        hash = decorator.decorate(undecorated_hash, [service_instance_1, service_instance_2])

        expect(hash).to match({
          foo: 'bar',
          included: {
            monkeys: %w(zach greg),
            organizations: [
              {
                guid: org1.guid,
              },
              {
                guid: org2.guid,
              }
            ]
          }
        })
      end

      context 'when instances share an org' do
        let(:space3) { Space.make(organization: org1) }
        let!(:service_instance_3) { ManagedServiceInstance.make(space: space3) }

        it 'does not duplicate the org' do
          decorator = described_class.new({ 'space.organization': ['name'] })
          hash = decorator.decorate({}, [service_instance_1, service_instance_3])
          expect(hash[:included][:organizations]).to have(1).element
        end
      end
    end

    describe '.match?' do
      it 'matches hashes containing key symbol `space.organization` and value `name`' do
        expect(described_class.match?({ 'space.organization': ['name'], other: ['bar'] })).to be_truthy
      end

      it 'matches hashes containing key symbol `space.organization` and value `guid`' do
        expect(described_class.match?({ 'space.organization': ['guid'], other: ['bar'] })).to be_truthy
      end

      it 'matches hashes containing key symbol `space.organization` and value `name,guid`' do
        expect(described_class.match?({ 'space.organization': ['name', 'guid', 'something'], other: ['bar'] })).to be_truthy
      end

      it 'does not match other values for a valid key' do
        expect(described_class.match?({ 'space.organization': ['foo'] })).to be_falsey
      end

      it 'does not match other key values' do
        expect(described_class.match?({ other: ['bar'] })).to be_falsey
      end

      it 'does not match non-hashes' do
        expect(described_class.match?('foo')).to be_falsey
      end
    end
  end
end
