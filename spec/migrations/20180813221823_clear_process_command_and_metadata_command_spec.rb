require 'spec_helper'

RSpec.describe 'clear process.command for buildpack-created apps', isolation: :truncation do
  def run_migration
    Sequel::Migrator.run(VCAP::CloudController::AppModel.db, tmp_migrations_dir, table: :my_fake_table)
  end

  let(:tmp_migrations_dir) { Dir.mktmpdir }

  before do
    FileUtils.cp(
      File.join(DBMigrator::SEQUEL_MIGRATIONS, '20180813221823_clear_process_command_and_metadata_command.rb'),
      tmp_migrations_dir,
    )
  end

  context "when a process's command matches the detected command from its app's droplet" do
    let!(:app) { VCAP::CloudController::AppModel.make }
    let!(:process) { VCAP::CloudController::ProcessModelFactory.make(app: app, command: 'detected-buildpack-web-command', type: 'web') }
    let!(:other_process) { VCAP::CloudController::ProcessModelFactory.make(app: app, command: 'detected-buildpack-worker-command', type: 'worker') }
    let!(:droplet) do
      VCAP::CloudController::DropletModel.make(
        process_types: {
          web: 'detected-buildpack-web-command',
          worker: 'detected-buildpack-worker-command',
        }
      )
    end

    before do
      app.update(droplet: droplet)
    end

    it "nils out the process's command" do
      run_migration

      expect(process.reload.command).to be_nil
      expect(other_process.reload.command).to be_nil
    end

    it 'releases the lock and users can update the process afterwards' do
      run_migration

      expect(process.reload.command).to be_nil

      process.update(command: 'new-command')
      expect(process.reload.command).to eq('new-command')
    end
  end

  context "when a process's command doesn't match the detected command from its app's droplet" do
    let!(:app) { VCAP::CloudController::AppModel.make }
    let!(:process) { VCAP::CloudController::ProcessModelFactory.make(app: app, command: 'api-command-web', type: 'web') }
    let!(:droplet) { VCAP::CloudController::DropletModel.make(app: app, process_types: { web: 'detected-command-web' }) }

    before do
      app.update(droplet: droplet)
    end

    it "does not modify the process's command" do
      run_migration

      expect(process.reload.command).to eq('api-command-web')
    end
  end

  context 'when the process has metadata with a command' do
    let(:command_a) { 'bundle exec rails s' }
    let(:command_b) { 'curl docs.cloudfoundry.org/start_command | sh' }
    let(:command_c) { 'php -f main.php' }

    let!(:app) { VCAP::CloudController::AppModel.make }
    let!(:process) { VCAP::CloudController::ProcessModelFactory.make(
      app: app,
      command: process_command,
      metadata: { command: process_metadata_command, console: true },
      type: 'web')
    }
    let!(:droplet) { VCAP::CloudController::DropletModel.make(app: app, process_types: { 'web' => droplet_command }) }

    before do
      app.update(droplet: droplet)
    end

    context 'when the process metadata command, droplet command, and process command are all equal' do
      let(:process_command) { command_a }
      let(:process_metadata_command) { command_a }
      let(:droplet_command) { command_a }

      it 'nils out everything except the droplet command' do
        run_migration

        expect(process.reload.command).to be_nil
        expect(process.reload.metadata['command']).to be_nil
        expect(process.reload.detected_start_command).to eq(command_a)
      end
    end

    context 'when the process metadata command and droplet command are equal and the process command is nil' do
      let(:process_command) { nil }
      let(:process_metadata_command) { command_a }
      let(:droplet_command) { command_a }

      it 'nils out everything except the droplet command' do
        run_migration

        expect(process.reload.command).to be_nil
        expect(process.reload.metadata['command']).to be_nil
        expect(process.reload.detected_start_command).to eq(command_a)
      end

      it 'does not nil out the non-command part of the process metadata' do
        run_migration

        expect(process.reload.metadata['console']).to eq true
      end
    end

    context 'when the process metadata command and droplet command are equal and the process command is ""' do
      let(:process_command) { '' }
      let(:process_metadata_command) { command_a }
      let(:droplet_command) { command_a }

      it 'nils out everything except the droplet command' do
        run_migration

        expect(process.reload.command).to be_nil
        expect(process.reload.metadata['command']).to be_nil
        expect(process.reload.detected_start_command).to eq command_a
      end
    end

    context 'when the process metadata command, droplet command, and process command are all different' do
      let(:process_command) { command_a }
      let(:process_metadata_command) { command_b }
      let(:droplet_command) { command_c }

      it 'nils out the process metadata command' do
        run_migration

        expect(process.reload.command).to eq(command_a)
        expect(process.reload.metadata['command']).to be_nil
        expect(process.reload.detected_start_command).to eq(command_c)
      end
    end

    context 'when the process metadata command and droplet command are equal and the process command is different' do
      let(:process_command) { command_a }
      let(:process_metadata_command) { command_b }
      let(:droplet_command) { command_b }

      it 'nils out the process metadata command' do
        run_migration

        expect(process.reload.command).to eq(command_a)
        expect(process.reload.metadata['command']).to be_nil
        expect(process.reload.detected_start_command).to eq(command_b)
      end
    end

    context 'when the process metadata command and the droplet command are different and the process command is nil' do
      let(:process_command) { nil }
      let(:process_metadata_command) { command_b }
      let(:droplet_command) { command_a }

      it 'sets the process command equal to the process metadata command and nils out the process metadata command' do
        run_migration

        expect(process.reload.command).to eq(command_b)
        expect(process.reload.metadata['command']).to be_nil
        expect(process.reload.detected_start_command).to eq(command_a)
      end
    end

    context 'when the process metadata command and the droplet command are different and the process command is ""' do
      let(:process_command) { '' }
      let(:process_metadata_command) { command_b }
      let(:droplet_command) { command_a }

      it 'promotes the metadata command to process command' do
        run_migration

        expect(process.reload.command).to eq command_b
        expect(process.reload.metadata['command']).to be_nil
        expect(process.reload.detected_start_command).to eq command_a
      end
    end

    context 'when the process metadata command exists and the droplet command and process command are nil' do
      let(:process_command) { nil }
      let(:process_metadata_command) { command_a }
      let(:droplet_command) { nil }

      it 'sets the process command equal to the process metadata command and nils out the process metadata command' do
        run_migration

        expect(process.reload.command).to eq(command_a)
        expect(process.reload.metadata['command']).to be_nil
        expect(process.reload.detected_start_command).to be_empty
      end
    end

    context 'when the process metadata command is different than the process command and the droplet command is nil' do
      let(:process_command) { command_a }
      let(:process_metadata_command) { command_b }
      let(:droplet_command) { nil }

      it 'nils out the process metadata command' do
        run_migration

        expect(process.reload.command).to eq(command_a)
        expect(process.reload.metadata['command']).to be_nil
        expect(process.reload.detected_start_command).to be_empty
      end
    end

    context 'when the process metadata command, the droplet command, and the process command are all nil' do
      let(:process_command) { nil }
      let(:process_metadata_command) { nil }
      let(:droplet_command) { nil }

      it 'keeps everything nil (what were you expecting?)' do
        run_migration

        expect(process.reload.command).to be_nil
        expect(process.reload.metadata['command']).to be_nil
        expect(process.reload.detected_start_command).to be_empty
      end
    end

    context 'when the process metadata command is different than the droplet command and the process command' do
      let(:process_command) { command_a }
      let(:process_metadata_command) { command_b }
      let(:droplet_command) { command_a }

      it 'nils out the process command and the process metadata command' do
        run_migration

        expect(process.reload.command).to be_nil
        expect(process.reload.metadata['command']).to be_nil
        expect(process.reload.detected_start_command).to eq(command_a)
      end
    end

    context 'when the process metadata command is equal to the process command and the droplet command is different' do
      let(:process_command) { command_a }
      let(:process_metadata_command) { command_a }
      let(:droplet_command) { command_b }

      it 'nils out the process metadata command' do
        run_migration

        expect(process.reload.command).to eq(command_a)
        expect(process.reload.metadata['command']).to be_nil
        expect(process.reload.detected_start_command).to eq(command_b)
      end
    end
  end

  context 'when the process has malformed metadata' do
    let!(:app) { VCAP::CloudController::AppModel.make }
    let!(:process) { VCAP::CloudController::ProcessModelFactory.make(app: app, command: process_command, type: 'web') }
    let!(:droplet) { VCAP::CloudController::DropletModel.make(app: app, process_types: { 'web' => droplet_command }) }
    let(:droplet_command) { 'command_a' }
    let(:process_command) { droplet_command }

    before do
      app.update(droplet: droplet)
      VCAP::CloudController::ProcessModel.db[:processes].where(guid: process.guid).update(metadata: '{} {bad json')
    end

    it 'still updates the process command' do
      expect {
        run_migration
      }.not_to raise_error

      expect(process.reload.command).to be_nil
      expect(process.reload.detected_start_command).to eq droplet_command
    end
  end

  context "when a droplet's process types are malformed" do
    let!(:app) { VCAP::CloudController::AppModel.make }
    let!(:process) { VCAP::CloudController::ProcessModelFactory.make(app: app, command: 'api-command-web', type: 'web', metadata: { command: 'start app' }) }
    let!(:droplet) { VCAP::CloudController::DropletModel.make(app: app, process_types: { web: 'detected-command-web' }) }

    before do
      app.update(droplet: droplet)
      VCAP::CloudController::DropletModel.db[:droplets].where(guid: droplet.guid).update(process_types: '{} {bad json')
    end

    it "does not modify the process's command or raise an error" do
      expect {
        run_migration
      }.not_to raise_error
      expect(process.reload.command).to eq('api-command-web')
    end

    it 'still nils the process metadata command' do
      run_migration

      expect(process.reload.metadata['command']).to be_nil
    end
  end

  context 'when a droplet has nil process_types' do
    let!(:app) { VCAP::CloudController::AppModel.make }
    let!(:process) { VCAP::CloudController::ProcessModelFactory.make(app: app, command: 'api-command-web', type: 'web') }

    before do
      VCAP::CloudController::DropletModel.make(app: app, process_types: nil)
    end

    it "does not modify the process's command or raise an error" do
      expect {
        run_migration
      }.not_to raise_error
      expect(process.reload.command).to eq('api-command-web')
    end
  end

  context "when an app doesn't have a droplet" do
    let!(:app1) { VCAP::CloudController::AppModel.make }
    let!(:process1) { VCAP::CloudController::ProcessModel.make(app: app1, command: 'api-command-web', type: 'web') }

    it "does not modify the process's command or raise an error" do
      expect(VCAP::CloudController::ProcessModel.count).to eq(1)

      run_migration

      expect(process1.reload.command).to eq('api-command-web')
    end
  end
end
