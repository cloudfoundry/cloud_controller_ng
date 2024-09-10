require 'spec_helper'
require 'decorators/field_service_instance_organization_decorator'
require 'field_decorator_spec_shared_examples'

module VCAP::CloudController
  RSpec.describe FieldServiceInstanceOrganizationDecorator do
    describe '.decorate' do
      let(:org1) { Organization.make(created_at: Time.now.utc - 1.second) }
      let(:org2) { Organization.make }

      let(:space1) { Space.make(organization: org1) }
      let(:space2) { Space.make(organization: org2) }

      let(:service_instance_1) { ManagedServiceInstance.make(space: space1) }
      let(:service_instance_2) { UserProvidedServiceInstance.make(space: space2) }

      before do
        allow(Permissions).to receive(:new).and_return(double(can_read_globally?: true))
      end

      it 'decorated the given hash with orgs names from service instances' do
        undecorated_hash = { foo: 'bar', included: { monkeys: %w[zach greg] } }
        decorator = described_class.new({ 'space.organization': %w[name foo] })

        hash = decorator.decorate(undecorated_hash, [service_instance_1, service_instance_2])

        expect(hash).to match({
                                foo: 'bar',
                                included: {
                                  monkeys: %w[zach greg],
                                  organizations: [
                                    {
                                      name: org1.name
                                    },
                                    {
                                      name: org2.name
                                    }
                                  ]
                                }
                              })
      end

      it 'decorated the given hash with orgs guids from service instances' do
        undecorated_hash = { foo: 'bar', included: { monkeys: %w[zach greg] } }
        decorator = described_class.new({ 'space.organization': %w[guid foo] })

        hash = decorator.decorate(undecorated_hash, [service_instance_1, service_instance_2])

        expect(hash).to match({
                                foo: 'bar',
                                included: {
                                  monkeys: %w[zach greg],
                                  organizations: [
                                    {
                                      guid: org1.guid
                                    },
                                    {
                                      guid: org2.guid
                                    }
                                  ]
                                }
                              })
      end

      context 'when instances share an org' do
        let(:space3) { Space.make(organization: org1) }
        let(:service_instance_3) { ManagedServiceInstance.make(space: space3) }

        it 'does not duplicate the org' do
          decorator = described_class.new({ 'space.organization': ['name'] })
          hash = decorator.decorate({}, [service_instance_1, service_instance_3])
          expect(hash[:included][:organizations]).to have(1).element
        end
      end

      context 'decorating relationships' do
        it 'includes the related resource correctly' do
          decorator = described_class.new({ 'space.organization': %w[name guid] })
          undecorated_hash = { foo: 'bar', included: { monkeys: %w[zach greg] } }
          relationship = [space1, space2, space1]

          hash = decorator.decorate(undecorated_hash, relationship)

          expect(hash).to match({
                                  foo: 'bar',
                                  included: {
                                    monkeys: %w[zach greg],
                                    organizations: [
                                      { name: org1.name, guid: org1.guid },
                                      { name: org2.name, guid: org2.guid }
                                    ]
                                  }
                                })
        end
      end
    end

    describe '.match?' do
      it_behaves_like 'field decorator match?', 'space.organization', %w[name guid]
    end
  end
end
