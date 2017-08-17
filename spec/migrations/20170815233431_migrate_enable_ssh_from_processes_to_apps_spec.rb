require 'spec_helper'

RSpec.describe 'Fill in enable_ssh flags for apps from existing processes', isolation: :truncation do
  let(:tmp_migrations_dir) { Dir.mktmpdir }
  let(:start_event_created_at) { Time.new(2017, 1, 1) }

  before do
    FileUtils.cp(
      File.join(DBMigrator::SEQUEL_MIGRATIONS, '20170815233431_migrate_enable_ssh_from_processes_to_apps.rb'),
      tmp_migrations_dir,
    )

    allow(VCAP::CloudController::AppObserver).to receive(:updated)
  end

  let!(:web_process) { VCAP::CloudController::ProcessModelFactory.make(type: 'web', guid: 'app-1') }
  let!(:nonweb_process) { VCAP::CloudController::ProcessModelFactory.make(type: 'nonweb', guid: 'app-1') }

  let!(:nonweb_process_alone) { VCAP::CloudController::ProcessModelFactory.make(type: 'nonweb', guid: '456',) }

  context 'apps with corresponding web processes with app settings set to true' do
    before do
      web_process.update(enable_ssh: true)
      web_process.app.update(enable_ssh: false)

      nonweb_process.update(enable_ssh: false)
      nonweb_process.app.update(enable_ssh: false)
    end

    it 'copies the ssh_enabled flag from web process to the app for the process and app with same guid' do
      Sequel::Migrator.run(VCAP::CloudController::AppModel.db, tmp_migrations_dir, table: :my_fake_table)
      expect(VCAP::CloudController::AppModel.where(guid: web_process.app.guid).first.enable_ssh).to eq(true)
    end
  end

  context 'apps with corresponding web processes with app settings set to false' do
    before do
      web_process.update(enable_ssh: false)
      web_process.app.update(enable_ssh: true)

      nonweb_process.update(enable_ssh: true)
      nonweb_process.app.update(enable_ssh: true)
    end

    it 'copies the ssh_enabled flag from the web process to the app for the process and app with same guid' do
      Sequel::Migrator.run(VCAP::CloudController::AppModel.db, tmp_migrations_dir, table: :my_fake_table)
      expect(VCAP::CloudController::AppModel.where(guid: web_process.app.guid).first.enable_ssh).to eq(false)
    end
  end
end
