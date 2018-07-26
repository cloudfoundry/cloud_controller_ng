require 'spec_helper'

RSpec.describe 'clear process.command for buildpack-created apps', isolation: :truncation do
  def run_migration
    Sequel::Migrator.run(VCAP::CloudController::AppModel.db, tmp_migrations_dir, table: :my_fake_table)
  end

  let(:tmp_migrations_dir) { Dir.mktmpdir }

  before do
    FileUtils.cp(
      File.join(DBMigrator::SEQUEL_MIGRATIONS, '20180726120275_clear_process_command_for_buildpacks.rb'),
      tmp_migrations_dir,
    )
  end

  context "when a process's command matches the detected command from its app's droplet" do
    let!(:app) { VCAP::CloudController::AppModel.make }
    let!(:process) { VCAP::CloudController::ProcessModelFactory.make(app: app, command: 'detected-command-web', type: 'web') }
    let!(:droplet) { VCAP::CloudController::DropletModel.make(process_types: { web: 'detected-command-web' }) }

    before do
      app.update(droplet: droplet)
    end

    it "nils out the process's command" do
      run_migration

      expect(process.reload.command).to be_nil
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

  context "when a droplet's process types are malformed" do
    let!(:app) { VCAP::CloudController::AppModel.make }
    let!(:process) { VCAP::CloudController::ProcessModelFactory.make(app: app, command: 'api-command-web', type: 'web') }
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
  end
end
