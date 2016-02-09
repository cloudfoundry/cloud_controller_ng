require 'spec_helper'

module VCAP::CloudController
  describe EnvironmentVariableGroup, type: :model do
    subject(:env_group) { EnvironmentVariableGroup.make }

    it { is_expected.to have_timestamp_columns }

    it_behaves_like 'a model with an encrypted attribute' do
      let(:encrypted_attr) { :environment_json }
      let(:attr_salt) { :salt }
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :name, :environment_json }
      it { is_expected.to import_attributes :environment_json }
    end

    describe '#staging' do
      context 'when the corresponding db object does not exist' do
        before do
          EnvironmentVariableGroup.dataset.destroy
        end

        it 'creates a new database object with the right name' do
          expect(EnvironmentVariableGroup).to receive(:create).with(name: 'staging')
          EnvironmentVariableGroup.staging
        end

        it 'initializes the object with an empty environment' do
          expect(EnvironmentVariableGroup.staging.environment_json).to eq({})
        end

        it 'updates the object on save' do
          staging = EnvironmentVariableGroup.staging
          staging.environment_json = { 'abc' => 'easy as 123' }
          staging.save

          expect(EnvironmentVariableGroup.staging.environment_json).to eq({ 'abc' => 'easy as 123' })
        end
      end

      context 'when the corresponding db object exists' do
        before do
          staging_group = EnvironmentVariableGroup.find(name: 'staging')
          staging_group.environment_json = { 'abc' => 123 }
          staging_group.save
        end

        it 'returns the existing object' do
          expect(EnvironmentVariableGroup.staging.environment_json).to eq('abc' => 123)
        end
      end
    end

    describe '#running' do
      context 'when the corresponding db object does not exist' do
        before do
          EnvironmentVariableGroup.dataset.destroy
        end

        it 'creates a new database object with the right name' do
          expect(EnvironmentVariableGroup).to receive(:create).with(name: 'running')
          EnvironmentVariableGroup.running
        end

        it 'initializes the object with an empty environment' do
          expect(EnvironmentVariableGroup.running.environment_json).to eq({})
        end

        it 'updates the object on save' do
          running = EnvironmentVariableGroup.running
          running.environment_json = { 'abc' => 'easy as 123' }
          running.save

          expect(EnvironmentVariableGroup.running.environment_json).to eq({ 'abc' => 'easy as 123' })
        end
      end

      context 'when the corresponding db object exists' do
        before do
          running_group = EnvironmentVariableGroup.find(name: 'running')
          running_group.environment_json = { 'abc' => 123 }
          running_group.save
        end

        it 'returns the existing object' do
          expect(EnvironmentVariableGroup.running.environment_json).to eq('abc' => 123)
        end
      end
    end

    describe 'environment_json encryption' do
      let(:long_env) { { 'many_os' => 'o' * 10_000 } }

      it 'works with long serialized environments' do
        var_group = EnvironmentVariableGroup.make(environment_json: long_env)
        var_group.reload
        expect(var_group.environment_json).to eq(long_env)
      end
    end
  end
end
