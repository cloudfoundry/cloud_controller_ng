require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::QuotaDefinition, type: :model do
    let(:quota_definition) { QuotaDefinition.make }

    it { is_expected.to have_timestamp_columns }

    describe 'Associations' do
      before do
        allow(SecurityContext).to receive(:admin?).and_return(true)
      end

      it { is_expected.to have_associated :organizations }
    end

    describe 'Validations' do
      it { is_expected.to validate_presence :name }
      it { is_expected.to validate_presence :non_basic_services_allowed }
      it { is_expected.to validate_presence :total_services }
      it { is_expected.to validate_presence :total_routes }
      it { is_expected.to validate_presence :memory_limit }
      it { is_expected.to validate_uniqueness :name }

      describe 'memory_limits' do
        it 'total memory_limit cannot be less than zero' do
          quota_definition.memory_limit = -1
          expect(quota_definition).not_to be_valid
          expect(quota_definition.errors.on(:memory_limit)).to include(:less_than_zero)

          quota_definition.memory_limit = 0
          expect(quota_definition).to be_valid
        end

        it 'instance_memory_limit cannot be less than zero' do
          quota_definition.instance_memory_limit = -2
          expect(quota_definition).not_to be_valid
          expect(quota_definition.errors.on(:instance_memory_limit)).to include(:invalid_instance_memory_limit)

          quota_definition.instance_memory_limit = -1
          expect(quota_definition).to be_valid
        end
      end
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :name, :non_basic_services_allowed, :total_services, :total_routes, :memory_limit, :trial_db_allowed, :instance_memory_limit }
      it { is_expected.to import_attributes :name, :non_basic_services_allowed, :total_services, :total_routes, :memory_limit, :trial_db_allowed, :instance_memory_limit }
    end

    describe '.default' do
      it 'returns the default quota' do
        expect(QuotaDefinition.default.name).to eq('default')
      end
    end

    describe '#destroy' do
      context 'when there is an associated organization' do
        it 'raises an AssociationNotEmpty error' do
          Organization.make(quota_definition: quota_definition)

          expect {
            quota_definition.destroy
          }.to raise_error VCAP::Errors::ApiError, /Please delete the organization associations for your quota definition./
          expect(QuotaDefinition[quota_definition.id]).to eq quota_definition
        end
      end

      context 'when there is no associated organization' do
        it 'deletes the quota_definition' do
          quota_definition.destroy
          expect(QuotaDefinition[quota_definition.id]).to be_nil
        end
      end
    end

    describe '#trial_db_allowed=' do
      it 'can be called on the model object' do
        quota_definition.trial_db_allowed = true
      end

      it 'will not change the value returned (deprecated)' do
        expect {
          quota_definition.trial_db_allowed = true
        }.to_not change {
          quota_definition
        }
      end
    end

    describe '#trial_db_allowed' do
      it 'always returns false (deprecated)' do
        [false, true].each do |allowed|
          quota_definition.trial_db_allowed = allowed
          expect(quota_definition.trial_db_allowed).to be false
        end
      end
    end

    describe '#to_hash' do
      it 'does not include org_usage when org_usage has not been set' do
        expect(quota_definition.to_hash).to_not include('org_usage')
      end

      it 'includes org_usage when org_usage has been set' do
        quota_definition.org_usage = 'someusage'
        expect(quota_definition.to_hash).to include('org_usage')
      end
    end
  end
end
