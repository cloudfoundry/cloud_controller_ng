require 'spec_helper'
require 'decorators/field_service_instance_space_decorator'
require 'field_decorator_spec_shared_examples'

module VCAP::CloudController
  RSpec.describe FieldServiceInstanceSpaceDecorator do
    describe '.decorate' do
      let(:org1) { Organization.make }
      let(:org2) { Organization.make }

      let(:space1) { Space.make(organization: org1) }
      let(:space2) { Space.make(organization: org2) }

      let!(:service_instance_1) { ManagedServiceInstance.make(space: space1) }
      let!(:service_instance_2) { UserProvidedServiceInstance.make(space: space2) }

      context 'when space guid, name and relationship.organizations are requested' do
        let(:decorator) { described_class.new({ space: ['relationships.organization', 'guid', 'name'] }) }

        it 'decorates the given hash with spaces guids and relationships to orgs from service instances' do
          undecorated_hash = { foo: 'bar', included: { monkeys: %w(zach greg) } }
          hash = decorator.decorate(undecorated_hash, [service_instance_1, service_instance_2])

          expect(hash).to match({
            foo: 'bar',
            included: {
              monkeys: %w(zach greg),
              spaces: [
                {
                  guid: space1.guid,
                  name: space1.name,
                  relationships: {
                    organization: {
                      data: {
                        guid: org1.guid
                      }
                    }
                  }
                },
                {
                  guid: space2.guid,
                  name: space2.name,
                  relationships: {
                    organization: {
                      data: {
                        guid: org2.guid
                      }
                    }
                  }
                }
              ]
            }
          })
        end
      end

      context 'when only space guids are requested' do
        it 'decorates the given hash with spaces guids' do
          decorator = described_class.new({ space: ['guid'] })
          undecorated_hash = { foo: 'bar', included: { monkeys: %w(zach greg) } }
          hash = decorator.decorate(undecorated_hash, [service_instance_1, service_instance_2])

          expect(hash).to match({
            foo: 'bar',
            included: {
              monkeys: %w(zach greg),
              spaces: [
                {
                  guid: space1.guid,
                },
                {
                  guid: space2.guid,
                }
              ]
            }
          })
        end
      end

      context 'when only space names are requested' do
        it 'decorates the given hash with spaces names' do
          decorator = described_class.new({ space: ['name'] })
          undecorated_hash = { foo: 'bar', included: { monkeys: %w(zach greg) } }
          hash = decorator.decorate(undecorated_hash, [service_instance_1, service_instance_2])

          expect(hash).to match({
            foo: 'bar',
            included: {
              monkeys: %w(zach greg),
              spaces: [
                {
                  name: space1.name,
                },
                {
                  name: space2.name,
                }
              ]
            }
          })
        end
      end

      context 'when only relationships.organization is requested' do
        it 'decorates the given hash with relationships to orgs' do
          decorator = described_class.new({ space: ['relationships.organization'] })
          undecorated_hash = { foo: 'bar', included: { monkeys: %w(zach greg) } }
          hash = decorator.decorate(undecorated_hash, [service_instance_1, service_instance_2])

          expect(hash).to match({
            foo: 'bar',
            included: {
              monkeys: %w(zach greg),
              spaces: [
                {
                  relationships: {
                    organization: {
                      data: {
                        guid: org1.guid
                      }
                    }
                  }
                },
                {
                  relationships: {
                    organization: {
                      data: {
                        guid: org2.guid
                      }
                    }
                  }
                }
              ]
            }
          })
        end
      end

      context 'when instances share a space' do
        let(:decorator) { described_class.new({ space: ['guid'] }) }
        let!(:service_instance_3) { ManagedServiceInstance.make(space: space1) }

        it 'does not duplicate the space' do
          hash = decorator.decorate({}, [service_instance_1, service_instance_3])
          expect(hash[:included][:spaces]).to have(1).element
        end
      end

      context 'decorating relationships' do
        it 'includes the related resource correctly' do
          decorator = described_class.new({ space: ['guid'] })
          undecorated_hash = { foo: 'bar', included: { monkeys: %w(zach greg) } }
          relationship = [space1, space2, space1]

          hash = decorator.decorate(undecorated_hash, relationship)

          expect(hash).to match({
            foo: 'bar',
            included: {
              monkeys: %w(zach greg),
              spaces: [
                {
                  guid: space1.guid,
                },
                {
                  guid: space2.guid,
                }
              ]
            }
          })
        end
      end
    end

    describe '.match?' do
      it_behaves_like 'field decorator match?', 'space', ['name', 'guid', 'relationships.organization']
    end
  end
end
