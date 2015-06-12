require 'spec_helper'

module VCAP::CloudController
  describe SpaceQuotaDefinition, type: :model do
    let(:space_quota_definition) { SpaceQuotaDefinition.make }

    it { is_expected.to have_timestamp_columns }

    describe 'Associations' do
      it { is_expected.to have_associated :organization, associated_instance: ->(space_quota) { space_quota.organization } }
      it { is_expected.to have_associated :spaces, associated_instance: ->(space_quota) { Space.make(organization: space_quota.organization) } }

      context 'organization' do
        it 'fails when changing' do
          expect { SpaceQuotaDefinition.make.organization = Organization.make }.to raise_error SpaceQuotaDefinition::OrganizationAlreadySet
        end
      end
    end

    describe 'Validations' do
      it { is_expected.to validate_presence :name }
      it { is_expected.to validate_presence :non_basic_services_allowed }
      it { is_expected.to validate_presence :total_services }
      it { is_expected.to validate_presence :total_routes }
      it { is_expected.to validate_presence :memory_limit }
      it { is_expected.to validate_presence :organization }
      it { is_expected.to validate_uniqueness [:organization_id, :name] }

      describe 'memory_limits' do
        it 'total memory_limit cannot be less than zero' do
          space_quota_definition.memory_limit = -1
          expect(space_quota_definition).not_to be_valid
          expect(space_quota_definition.errors.on(:memory_limit)).to include(:less_than_zero)

          space_quota_definition.memory_limit = 0
          expect(space_quota_definition).to be_valid
        end

        it 'instance_memory_limit cannot be less than zero' do
          space_quota_definition.instance_memory_limit = -2
          expect(space_quota_definition).not_to be_valid
          expect(space_quota_definition.errors.on(:instance_memory_limit)).to include(:invalid_instance_memory_limit)

          space_quota_definition.instance_memory_limit = -1
          expect(space_quota_definition).to be_valid
        end
      end
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :name, :organization_guid, :non_basic_services_allowed, :total_services, :total_routes, :memory_limit, :instance_memory_limit }
      it { is_expected.to import_attributes :name, :organization_guid, :non_basic_services_allowed, :total_services, :total_routes, :memory_limit, :instance_memory_limit }
    end

    describe '#destroy' do
      it 'nullifies space_quota_definition on space' do
        space  = Space.make(organization: space_quota_definition.organization)
        space.space_quota_definition = space_quota_definition
        space.save
        expect { space_quota_definition.destroy }.to change { space.reload.space_quota_definition }.from(space_quota_definition).to(nil)
      end
    end
  end
end
