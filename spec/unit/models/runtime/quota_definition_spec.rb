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

        it 'instance_memory_limit cannot be less than -1' do
          quota_definition.instance_memory_limit = -2
          expect(quota_definition).not_to be_valid
          expect(quota_definition.errors.on(:instance_memory_limit)).to include(:invalid_instance_memory_limit)

          quota_definition.instance_memory_limit = -1
          expect(quota_definition).to be_valid
        end
      end

      it 'total_private_domains cannot be less than -1' do
        quota_definition.total_private_domains = -2
        expect(quota_definition).not_to be_valid
        expect(quota_definition.errors.on(:total_private_domains)).to include(:invalid_total_private_domains)

        quota_definition.total_private_domains = -1
        expect(quota_definition).to be_valid
      end

      it 'app_instance_limit cannot be less than -1' do
        quota_definition.app_instance_limit = -2
        expect(quota_definition).not_to be_valid
        expect(quota_definition.errors.on(:app_instance_limit)).to include(:invalid_app_instance_limit)

        quota_definition.app_instance_limit = -1
        expect(quota_definition).to be_valid
      end
    end

    describe 'Serialization' do
      it {
        is_expected.to export_attributes :name, :non_basic_services_allowed, :total_services, :total_routes,
                                         :total_private_domains, :memory_limit, :trial_db_allowed, :instance_memory_limit,
                                         :app_instance_limit
      }
      it {
        is_expected.to import_attributes :name, :non_basic_services_allowed, :total_services, :total_routes,
                                         :total_private_domains, :memory_limit, :trial_db_allowed, :instance_memory_limit,
                                         :app_instance_limit
      }
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
  end
end
