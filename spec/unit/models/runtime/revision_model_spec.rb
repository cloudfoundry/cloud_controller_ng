require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RevisionModel do
    describe '#commands_by_process_type' do
      let!(:droplet) do
        DropletModel.make(
          process_types: {
            'web' => 'droplet_web_command',
            'worker' => 'droplet_worker_command',
            'nil_process' => 'droplet_nil_process_command',
          })
      end
      let(:revision) { FactoryBot.create(:revision, droplet: droplet) }
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
    end

    describe '#add_process_command' do
      let(:revision) { FactoryBot.create(:revision) }

      it 'creates a RevisionProcessCommandModel' do
        expect {
          revision.add_command_for_process_type('other_process', 'doing some stuff')
        }.to change { RevisionProcessCommandModel.count }.by(1)

        command = RevisionProcessCommandModel.last
        expect(command.process_type).to eq 'other_process'
        expect(command.process_command).to eq 'doing some stuff'
      end
    end

    describe '#out_of_date_reasons' do
      let(:app) { FactoryBot.create(:app, revisions_enabled: true, environment_variables: { 'key' => 'value' }) }
      let(:droplet) do
        DropletModel.make(
          app: app,
          process_types: {
            'web' => 'droplet_web_command',
            'worker' => 'droplet_worker_command',
          })
      end
      let(:revision) { FactoryBot.create(:revision, app: app, droplet: app.droplet, environment_variables: app.environment_variables) }
      let!(:older_web_process) { ProcessModel.make(app: app, type: 'web', command: 'run my app', created_at: 2.minutes.ago) }
      let!(:worker_process) { ProcessModel.make(app: app, type: 'worker') }

      before do
        app.update(droplet: droplet)
        RevisionProcessCommandModel.make(revision: revision, process_type: older_web_process.type, process_command: older_web_process.command)
        RevisionProcessCommandModel.make(revision: revision, process_type: worker_process.type, process_command: worker_process.command)
      end

      context 'when there is a new droplet' do
        it 'adds a new droplet description' do
          new_droplet = DropletModel.make(app: app)
          app.update(droplet: new_droplet)

          expect(revision.out_of_date_reasons).to eq(['New droplet deployed.'])
        end
      end

      context 'when there are new env vars' do
        it 'adds a new env var description' do
          app.update(environment_variables: { 'key' => 'value2' })

          expect(revision.out_of_date_reasons).to eq(['New environment variables deployed.'])
        end
      end

      context 'when custom start commands are added' do
        it 'add new custom start command description' do
          worker_process.update(command: './start-my-worker')

          expect(revision.out_of_date_reasons).to eq(["Custom start command added for 'worker' process."])
        end
      end

      context 'when custom start commands are removed' do
        it 'add removed custom start command description' do
          older_web_process.update(command: nil)

          expect(revision.out_of_date_reasons).to eq(["Custom start command removed for 'web' process."])
        end
      end

      context 'when custom start commands are changed' do
        it 'add changed custom start command description' do
          older_web_process.update(command: '.some-other-web-command')

          expect(revision.out_of_date_reasons).to eq(["Custom start command updated for 'web' process."])
        end
      end

      context 'when process types are added' do
        it 'add changed custom start command description' do
          ProcessModel.make(app: app, type: 'other-type', command: 'run my app', created_at: 2.minutes.ago)

          expect(revision.out_of_date_reasons).to eq(["New process type 'other-type' added."])
        end
      end

      context 'when process types are removed' do
        it 'add changed custom start command description' do
          worker_process.delete

          expect(revision.out_of_date_reasons).to eq(["Process type 'worker' removed."])
        end
      end

      context 'when there are multiple reasons' do
        it 'adds descriptions in alphabetical order' do
          new_droplet = DropletModel.make(app: app)
          app.update(droplet: new_droplet)
          app.update(environment_variables: { 'key' => 'value2' })
          older_web_process.update(command: nil)
          ProcessModel.make(app: app, type: 'other-type', command: 'run my app', created_at: 2.minutes.ago)

          expect(revision.out_of_date_reasons).
            to eq([
              "Custom start command removed for 'web' process.",
              'New droplet deployed.',
              'New environment variables deployed.',
              "New process type 'other-type' added."
            ])
        end
      end
    end
  end
end
