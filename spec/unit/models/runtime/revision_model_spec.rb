require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RevisionModel do
    let!(:droplet) do
      DropletModel.make(
        process_types: {
          'web' => 'droplet_web_command',
          'worker' => 'droplet_worker_command',
          'droplet_only' => 'droplet_only_command',
        })
    end
    let(:revision) { RevisionModel.make(droplet: droplet) }

    describe 'validations' do
      context 'when a droplet_guid is not present' do
        let(:revision) do
          RevisionModel.new(droplet_guid: nil, app: AppModel.make)
        end

        it 'it is not valid' do
          expect(revision.valid?).to be false
        end
      end

      context 'when a app_guid is not present' do
        let(:revision) { RevisionModel.make }

        it 'it is not valid' do
          revision.app_guid = nil
          expect(revision.valid?).to be false
        end
      end
    end

    describe 'process_commands' do
      let!(:non_droplet_process_command) do
        RevisionProcessCommandModel.make(
          revision: revision,
          process_type: 'non_droplet',
          process_command: 'non_droplet_command',
        )
      end

      before do
        RevisionProcessCommandModel.where(
          revision: revision,
          process_type: 'worker',
        ).update(process_command: 'on the railroad')
      end

      describe '#commands_by_process_type' do
        it 'returns a hash of process types to commands' do
          expect(revision.commands_by_process_type).to eq({
            'web' => nil,
            'worker' => 'on the railroad',
            'droplet_only' => nil,
            'non_droplet' => 'non_droplet_command',
          })
        end
      end

      describe '#add_process_command' do
        let(:revision) { RevisionModel.make }

        it 'creates a RevisionProcessCommandModel' do
          expect {
            revision.add_command_for_process_type('other_process', 'doing some stuff')
          }.to change { RevisionProcessCommandModel.count }.by(1)

          command = RevisionProcessCommandModel.last
          expect(command.process_type).to eq 'other_process'
          expect(command.process_command).to eq 'doing some stuff'
        end
      end
    end

    describe 'when the env vars on the big side of the encrypted column' do
      let(:env_vars) { { 'foo' => SecureRandom.base64(12000) } }
      let(:app) { AppModel.make(environment_variables: env_vars) }
      let(:revision) { RevisionModel.make(environment_variables: env_vars) }
      it 'allows it' do
        expect(app.environment_variables).to eq(revision.environment_variables)
      end
    end
  end
end
