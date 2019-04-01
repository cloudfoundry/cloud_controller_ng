require 'spec_helper'

RSpec.describe 'Backfill web processes', isolation: :truncation do
  let(:tmp_migrations_dir) { Dir.mktmpdir }

  before do
    FileUtils.cp(
      File.join(DBMigrator::SEQUEL_MIGRATIONS, '20180523205142_backfill_web_processes_for_v3_apps.rb'),
      tmp_migrations_dir,
    )
  end

  let(:app_with_web_process) { VCAP::CloudController::AppModel.create(guid: 'a-with-web-process', name: 'app_with_web_process') }
  let!(:app_with_no_processes) { VCAP::CloudController::AppModel.create(guid: 'b-with-no-processes', name: 'app_with_no_processes') }
  let(:app_with_no_web_processes) { VCAP::CloudController::AppModel.create(guid: 'c-with-no-web-processes', name: 'app_with_no_web_process') }
  let(:app_with_mixed_processes) { VCAP::CloudController::AppModel.create(guid: 'd-with-mixed-processes', name: 'app_with_mixed_processes') }
  let!(:started_app_with_no_processes) do
    VCAP::CloudController::AppModel.create(
      guid: 'e-with-no-processes',
      name: 'started_app_with_no_processes',
      desired_state: VCAP::CloudController::ProcessModel::STARTED
    )
  end

  before do
    TestConfig.override(
      default_app_memory: 393,
      default_app_disk_in_mb: 71,
    )

    app_with_no_processes
    VCAP::CloudController::ProcessModelFactory.make(app: app_with_web_process, type: 'web')
    VCAP::CloudController::ProcessModelFactory.make(app: app_with_no_web_processes, type: 'not-web')
    VCAP::CloudController::ProcessModelFactory.make(app: app_with_mixed_processes, type: 'web')
    VCAP::CloudController::ProcessModelFactory.make(app: app_with_mixed_processes, type: 'not-web')
  end

  context 'when an app has a web process' do
    context 'and it has other non-web processes' do
      it 'does not change the existing processes' do
        app_guid = app_with_mixed_processes.guid
        web_process = VCAP::CloudController::ProcessModel.first(app_guid: app_guid, type: VCAP::CloudController::ProcessTypes::WEB)
        non_web_process = VCAP::CloudController::ProcessModel.first(app_guid: app_guid, type: 'not-web')

        expect {
          Sequel::Migrator.run(VCAP::CloudController::AppModel.db, tmp_migrations_dir, table: :my_fake_table)
        }.not_to change { VCAP::CloudController::ProcessModel.where(app_guid: app_guid).count }

        reloaded_web_process = VCAP::CloudController::ProcessModel.first(app_guid: app_guid, type: VCAP::CloudController::ProcessTypes::WEB)
        reloaded_non_web_process = VCAP::CloudController::ProcessModel.first(app_guid: app_guid, type: 'not-web')

        expect(web_process).to eq(reloaded_web_process)
        expect(non_web_process).to eq(reloaded_non_web_process)
      end
    end

    context 'and no other processes' do
      it 'does not change the existing processes' do
        app_guid = app_with_web_process.guid
        web_process = VCAP::CloudController::ProcessModel.first(app_guid: app_guid, type: VCAP::CloudController::ProcessTypes::WEB)

        expect {
          Sequel::Migrator.run(VCAP::CloudController::AppModel.db, tmp_migrations_dir, table: :my_fake_table)
        }.not_to change { VCAP::CloudController::ProcessModel.where(app_guid: app_guid).count }

        reloaded_web_process = VCAP::CloudController::ProcessModel.first(app_guid: app_guid, type: VCAP::CloudController::ProcessTypes::WEB)

        expect(web_process).to eq(reloaded_web_process)
      end
    end
  end

  context 'when an app has no web processes' do
    context 'when the app is STARTED' do
      it 'adds an empty web process' do
        app_guid = started_app_with_no_processes.guid
        expect(VCAP::CloudController::ProcessModel.where(app_guid: app_guid, type: VCAP::CloudController::ProcessTypes::WEB).count).to eq(0)

        Sequel::Migrator.run(VCAP::CloudController::AppModel.db, tmp_migrations_dir, table: :my_fake_table)

        expect(VCAP::CloudController::ProcessModel.where(app_guid: app_guid, type: VCAP::CloudController::ProcessTypes::WEB).count).to eq(1)
        process = VCAP::CloudController::ProcessModel.find(app_guid: app_guid, type: VCAP::CloudController::ProcessTypes::WEB)

        expect(process.guid).to eq app_guid
        expect(process.state).to eq 'STARTED'
      end
    end

    context 'and it has other non-web processes' do
      it 'adds an empty web process' do
        app_guid = app_with_no_web_processes.guid
        expect(VCAP::CloudController::ProcessModel.where(app_guid: app_guid, type: VCAP::CloudController::ProcessTypes::WEB).count).to eq(0)

        Sequel::Migrator.run(VCAP::CloudController::AppModel.db, tmp_migrations_dir, table: :my_fake_table)

        expect(VCAP::CloudController::ProcessModel.where(app_guid: app_guid, type: VCAP::CloudController::ProcessTypes::WEB).count).to eq(1)
        process = VCAP::CloudController::ProcessModel.find(app_guid: app_guid, type: VCAP::CloudController::ProcessTypes::WEB)

        expect(process.guid).to eq app_guid
        expect(process.instances).to eq 0
        expect(process.command).to eq nil
        expect(process.memory).to eq 393
        expect(process.disk_quota).to eq 71
        expect(process.state).to eq 'STOPPED'
        expect(process.diego).to be true
        expect(process.health_check_type).to eq 'port'
        expect(process.enable_ssh).to eq app_with_no_web_processes.enable_ssh
      end
    end

    context 'and no other processes' do
      it 'adds an empty web process' do
        app_guid = app_with_no_processes.guid
        expect(VCAP::CloudController::ProcessModel.where(app_guid: app_guid, type: VCAP::CloudController::ProcessTypes::WEB).count).to eq(0)

        Sequel::Migrator.run(VCAP::CloudController::AppModel.db, tmp_migrations_dir, table: :my_fake_table)

        expect(VCAP::CloudController::ProcessModel.where(app_guid: app_guid, type: VCAP::CloudController::ProcessTypes::WEB).count).to eq(1)
        process = VCAP::CloudController::ProcessModel.find(app_guid: app_guid, type: VCAP::CloudController::ProcessTypes::WEB)

        expect(process.guid).to eq app_guid
        expect(process.instances).to eq 0
        expect(process.command).to eq nil
        expect(process.memory).to eq 393
        expect(process.disk_quota).to eq 71
        expect(process.state).to eq 'STOPPED'
        expect(process.diego).to be true
        expect(process.health_check_type).to eq 'port'
        expect(process.enable_ssh).to eq app_with_no_processes.enable_ssh
      end
    end
  end
end
