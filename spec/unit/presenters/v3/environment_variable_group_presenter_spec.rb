require 'spec_helper'
require 'presenters/v3/environment_variable_group_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe EnvironmentVariableGroupPresenter do
    before {
      VCAP::CloudController::EnvironmentVariableGroup.find(name: 'running').update(environment_json: { 'foo' => 'burger_king' })
    }

    let(:running_env_group) { VCAP::CloudController::EnvironmentVariableGroup.running }

    describe '#to_hash' do
      let(:result) { EnvironmentVariableGroupPresenter.new(running_env_group).to_hash }

      describe 'links' do
        it 'has self link' do
          expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/environment_variable_groups/running")
        end
      end

      it 'presents the feature flag with those fields' do
        expect(result[:name]).to eq(running_env_group.name)
        expect(result[:var]).to eq(running_env_group.environment_json)
        expect(result[:updated_at]).to eq(running_env_group.updated_at)
      end
    end
  end
end
