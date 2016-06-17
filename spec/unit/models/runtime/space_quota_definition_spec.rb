require 'spec_helper'

module VCAP::CloudController
  RSpec.describe SpaceQuotaDefinition, type: :model do
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

        it 'instance_memory_limit cannot be less than -1' do
          space_quota_definition.instance_memory_limit = -2
          expect(space_quota_definition).not_to be_valid
          expect(space_quota_definition.errors.on(:instance_memory_limit)).to include(:invalid_instance_memory_limit)

          space_quota_definition.instance_memory_limit = -1
          expect(space_quota_definition).to be_valid
        end
      end

      describe 'app_instance_limit' do
        it 'cannot be less than -1' do
          space_quota_definition.app_instance_limit = -2
          expect(space_quota_definition).not_to be_valid
          expect(space_quota_definition.errors.on(:app_instance_limit)).to include(:invalid_app_instance_limit)

          space_quota_definition.app_instance_limit = -1
          expect(space_quota_definition).to be_valid
        end
      end

      describe 'app_task_limit' do
        it 'cannot be less than -1' do
          space_quota_definition.app_task_limit = -2
          expect(space_quota_definition).not_to be_valid
          expect(space_quota_definition.errors.on(:app_task_limit)).to include(:invalid_app_task_limit)

          space_quota_definition.app_task_limit = -1
          expect(space_quota_definition).to be_valid
        end
      end

      describe 'total_reserved_route_ports' do
        let(:err_msg) do
          'Total reserved ports must be -1, 0, or a positive integer, must ' \
            'be less than or equal to total routes, and must be less than or ' \
            'equal to total reserved ports for the organization quota.'
        end
        it 'cannot be less than -1' do
          space_quota_definition.total_reserved_route_ports = -2
          expect(space_quota_definition).not_to be_valid
          expect(space_quota_definition.errors.on(:total_reserved_route_ports).first).to eq(err_msg)

          space_quota_definition.total_reserved_route_ports = -1
          expect(space_quota_definition).to be_valid
        end

        context 'with total_reserved_route_ports set on the org' do
          before do
            org_quota_definition = space_quota_definition.organization.quota_definition
            org_quota_definition.total_reserved_route_ports = 10
            org_quota_definition.save
          end

          it "should not exceed space's total_routes" do
            space_quota_definition.total_reserved_route_ports = 11
            space_quota_definition.total_routes = 8
            expect(space_quota_definition).not_to be_valid
            expect(space_quota_definition.errors.on(:total_reserved_route_ports)).to contain_exactly(err_msg)
          end

          it "should not exceed org's total_reserved_route_ports" do
            space_quota_definition.total_reserved_route_ports = 11
            expect(space_quota_definition).not_to be_valid
            expect(space_quota_definition.errors.on(:total_reserved_route_ports)).to contain_exactly(err_msg)

            space_quota_definition.total_routes = -1
            space_quota_definition.total_reserved_route_ports = 11
            expect(space_quota_definition).not_to be_valid
            expect(space_quota_definition.errors.on(:total_reserved_route_ports)).to contain_exactly(err_msg)

            space_quota_definition.total_reserved_route_ports = 10
            expect(space_quota_definition).to be_valid

            space_quota_definition.total_reserved_route_ports = 9
            expect(space_quota_definition).to be_valid

            org_quota_definition = space_quota_definition.organization.quota_definition
            org_quota_definition.total_reserved_route_ports = -1
            org_quota_definition.save

            space_quota_definition.total_reserved_route_ports = 1_000
            expect(space_quota_definition).to be_valid
          end
        end

        it 'should not exceed total routes for the same space' do
          space_quota_definition.total_routes = 5

          space_quota_definition.total_reserved_route_ports = 4
          expect(space_quota_definition).to be_valid

          space_quota_definition.total_reserved_route_ports = 5
          expect(space_quota_definition).to be_valid

          space_quota_definition.total_reserved_route_ports = 6
          expect(space_quota_definition).to_not be_valid
          expect(space_quota_definition.errors.on(:total_reserved_route_ports)).to include(err_msg)
        end

        it 'can take any value if space quota for total_routes is set to -1' do
          space_quota_definition.total_routes = -1
          space_quota_definition.total_reserved_route_ports = 4
          expect(space_quota_definition).to be_valid

          space_quota_definition.total_reserved_route_ports = -1
          expect(space_quota_definition).to be_valid

          space_quota_definition.total_reserved_route_ports = 0
          expect(space_quota_definition).to be_valid
        end
      end

      it 'total_service_keys cannot be less than -1' do
        space_quota_definition.total_service_keys = -2
        expect(space_quota_definition).not_to be_valid
        expect(space_quota_definition.errors.on(:total_service_keys)).to include(:invalid_total_service_keys)

        space_quota_definition.total_service_keys = -1
        expect(space_quota_definition).to be_valid
      end
    end

    describe 'Serialization' do
      it do
        is_expected.to export_attributes :name, :organization_guid, :non_basic_services_allowed, :total_services,
          :total_routes, :memory_limit, :instance_memory_limit, :app_instance_limit, :app_task_limit,
          :total_service_keys, :total_reserved_route_ports
      end

      it do
        is_expected.to import_attributes :name, :organization_guid, :non_basic_services_allowed, :total_services,
          :total_routes, :memory_limit, :instance_memory_limit, :app_instance_limit, :app_task_limit,
          :total_service_keys, :total_reserved_route_ports
      end
    end

    describe '#destroy' do
      it 'nullifies space_quota_definition on space' do
        space = Space.make(organization: space_quota_definition.organization)
        space.space_quota_definition = space_quota_definition
        space.save
        expect { space_quota_definition.destroy }.to change { space.reload.space_quota_definition }.from(space_quota_definition).to(nil)
      end
    end
  end
end
