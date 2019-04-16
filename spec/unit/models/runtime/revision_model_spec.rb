require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RevisionModel do
    let!(:droplet) do
      DropletModel.make(
        process_types: {
          'web' => 'droplet_web_command',
          'worker' => 'droplet_worker_command',
          'nil_process' => 'droplet_nil_process_command',
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
        let(:revision) do
          RevisionModel.make_unsaved(app: nil)
        end

        it 'it is not valid' do
          expect(revision.valid?).to be false
        end
      end
    end

    describe 'process_commands' do
      let!(:revision_web_process_command) do
        RevisionProcessCommandModel.make(
          revision: revision,
          process_type: ProcessTypes::WEB,
          process_command: 'foo rackup stuff',
        )
      end

      let!(:revision_worker_process_command) do
        RevisionProcessCommandModel.make(
          revision: revision,
          process_type: 'worker',
          process_command: 'on the railroad',
        )
      end

      it 'returns a hash of process types to commands' do
        expect(revision.commands_by_process_type).to eq({
          'web' => 'foo rackup stuff',
          'worker' => 'on the railroad',
          'nil_process' => nil,
        })
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
  end
end
