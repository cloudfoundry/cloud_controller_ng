require 'spec_helper'
require 'actions/environment_variable_group_update'

module VCAP::CloudController
  RSpec.describe EnvironmentVariableGroupUpdate do
    subject { EnvironmentVariableGroupUpdate.new }

    let(:env_var_group) { EnvironmentVariableGroup.running }
    let(:existing_environment_variables) do
      {
        'override' => 'value-to-override',
        'preserve' => 'value-to-keep'
      }
    end

    before do
      env_var_group.update(environment_json: existing_environment_variables)
    end

    describe '#patch' do
      let(:request_environment_variables) do
        { override: 'new-value', new: 'env' }
      end

      let(:message) do
        UpdateEnvironmentVariablesMessage.new({ var: request_environment_variables })
      end

      it 'patches the apps environment_variables' do
        expect(env_var_group.environment_json).to eq(existing_environment_variables)

        subject.patch(env_var_group, message)
        env_var_group.reload

        expect(env_var_group.environment_json).to eq({
          'override' => 'new-value',
          'preserve' => 'value-to-keep',
          'new' => 'env',
        })
      end

      context 'when the app does not have any existing environment variables' do
        let(:existing_environment_variables) do
          nil
        end

        it 'patches the apps environment_variables' do
          expect(env_var_group.environment_json).to eq(existing_environment_variables)

          subject.patch(env_var_group, message)
          env_var_group.reload

          expect(env_var_group.environment_json).to eq({
            'override' => 'new-value',
            'new' => 'env',
          })
        end
      end

      context 'when a requested environment variable has a nil value' do
        let(:request_environment_variables) { { override: nil } }

        it 'removes the environment variable' do
          expect(env_var_group.environment_json).to eq(existing_environment_variables)

          subject.patch(env_var_group, message)
          env_var_group.reload

          expect(env_var_group.environment_json).to eq({
            'preserve' => 'value-to-keep',
          })
        end
      end

      context 'when a environment variable hash is empty' do
        let(:request_environment_variables) { {} }

        it 'should not change the apps environment variables' do
          expect(env_var_group.environment_json).to eq(existing_environment_variables)

          subject.patch(env_var_group, message)
          env_var_group.reload

          expect(env_var_group.environment_json).to eq(existing_environment_variables)
        end
      end
    end
  end
end
