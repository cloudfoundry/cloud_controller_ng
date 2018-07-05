require 'spec_helper'

RSpec.describe 'Sets missing attributes for previously backfilled processes', isolation: :truncation do
  let(:tmp_migrations_dir) { Dir.mktmpdir }

  before do
    FileUtils.cp(
      File.join(DBMigrator::SEQUEL_MIGRATIONS, '20180703233121_set_missing_fields_for_backfilled_web_processes.rb'),
      tmp_migrations_dir,
    )
  end

  # * memory = capi-release default
  # * disk_quota = capi-release default
  # * file_descriptors = capi-release default
  # * enable_ssh = 0
  #
  context 'when there are processes with null values for memory, disk_quota, file_descriptors, or enable_ssh' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    let!(:unaffected_process) do
      VCAP::CloudController::ProcessModelFactory.make(
        type: 'web',
        guid: 'app-1',
        memory: 350,
        disk_quota: 1234,
        file_descriptors: 9000,
        enable_ssh: false
      )
    end

    before do
      process_hash_one = {
        guid: 'process-one-guid',
        app_guid: app_model.guid,
        type: 'web',
        instances: 0,
        memory: nil,
        disk_quota: nil,
        file_descriptors: nil,
        enable_ssh: nil,
        state: app_model.desired_state,
        diego: true,
        health_check_type: 'port'
      }
      process_hash_two = {
        guid: 'process-two-guid',
        app_guid: app_model.guid,
        type: 'web',
        instances: 0,
        memory: nil,
        disk_quota: nil,
        file_descriptors: nil,
        enable_ssh: nil,
        state: app_model.desired_state,
        diego: true,
        health_check_type: 'port'
      }

      VCAP::CloudController::ProcessModel.db[:processes].insert(process_hash_one)
      VCAP::CloudController::ProcessModel.db[:processes].insert(process_hash_two)
    end

    it 'sets the missing fields on all affected processes' do
      process_one = VCAP::CloudController::ProcessModel.first(guid: 'process-one-guid').reload
      expect(process_one.memory).to be_nil
      expect(process_one.disk_quota).to be_nil
      expect(process_one.file_descriptors).to be_nil

      process_two = VCAP::CloudController::ProcessModel.first(guid: 'process-two-guid').reload
      expect(process_two.memory).to be_nil
      expect(process_two.disk_quota).to be_nil
      expect(process_two.file_descriptors).to be_nil
      Sequel::Migrator.run(VCAP::CloudController::AppModel.db, tmp_migrations_dir, table: :my_fake_table)

      process_one.reload
      expect(process_one.memory).to eq(1024)
      expect(process_one.disk_quota).to eq(1024)
      expect(process_one.file_descriptors).to eq(16384)

      process_two.reload
      expect(process_two.memory).to eq(1024)
      expect(process_two.disk_quota).to eq(1024)
      expect(process_two.file_descriptors).to eq(16384)
    end

    it 'ignores the processes that did not have missing data' do
      expect {
        Sequel::Migrator.run(VCAP::CloudController::AppModel.db, tmp_migrations_dir, table: :my_fake_table)
      }.not_to change { unaffected_process.reload.to_hash }

      unaffected_process.reload
      expect(unaffected_process.memory).to eq(350)
      expect(unaffected_process.disk_quota).to eq(1234)
      expect(unaffected_process.file_descriptors).to eq(9000)

      # ProcessModel redefines enable_ssh to point to its parent AppModel
      # To view what we set this to we need to fetch the value directly from the database
      process_record = VCAP::CloudController::ProcessModel.db[:processes].where(guid: unaffected_process.guid).first
      expect(process_record[:enable_ssh]).to eq(false)
    end
  end

  context 'when a process has a null value for memory' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    before do
      process_hash = {
        guid: app_model.guid,
        app_guid: app_model.guid,
        type: 'web',
        instances: 0,
        memory: nil,
        disk_quota: 1234,
        file_descriptors: 9000,
        enable_ssh: false,
        state: app_model.desired_state,
        diego: true,
        health_check_type: 'port'
      }

      VCAP::CloudController::ProcessModel.db[:processes].insert(process_hash)
    end

    it 'sets the memory value to the capi-release default' do
      process = VCAP::CloudController::ProcessModel.first(guid: app_model.guid).reload
      expect(process.memory).to be_nil
      Sequel::Migrator.run(VCAP::CloudController::AppModel.db, tmp_migrations_dir, table: :my_fake_table)

      process.reload
      expect(process.memory).to eq(1024)
      expect(process.disk_quota).to eq(1234)
      expect(process.file_descriptors).to eq(9000)

      # ProcessModel redefines enable_ssh to point to its parent AppModel
      # To view what we set this to we need to fetch the value directly from the database
      process_record = VCAP::CloudController::ProcessModel.db[:processes].where(guid: app_model.guid).first
      expect(process_record[:enable_ssh]).to eq(false)
    end
  end

  context 'when a process has a null value for disk_quota' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    before do
      process_hash = {
        guid: app_model.guid,
        app_guid: app_model.guid,
        type: 'web',
        instances: 0,
        memory: 117,
        disk_quota: nil,
        file_descriptors: 9000,
        enable_ssh: false,
        state: app_model.desired_state,
        diego: true,
        health_check_type: 'port'
      }

      VCAP::CloudController::ProcessModel.db[:processes].insert(process_hash)
    end

    it 'sets the disk_quota value to the capi-release default' do
      process = VCAP::CloudController::ProcessModel.first(guid: app_model.guid).reload
      expect(process.disk_quota).to be_nil
      Sequel::Migrator.run(VCAP::CloudController::AppModel.db, tmp_migrations_dir, table: :my_fake_table)

      process.reload
      expect(process.memory).to eq(117)
      expect(process.disk_quota).to eq(1024)
      expect(process.file_descriptors).to eq(9000)

      # ProcessModel redefines enable_ssh to point to its parent AppModel
      # To view what we set this to we need to fetch the value directly from the database
      process_record = VCAP::CloudController::ProcessModel.db[:processes].where(guid: app_model.guid).first
      expect(process_record[:enable_ssh]).to eq(false)
    end
  end

  context 'when a process has a null value for file_descriptors' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    before do
      process_hash = {
        guid: app_model.guid,
        app_guid: app_model.guid,
        type: 'web',
        instances: 0,
        memory: 117,
        disk_quota: 1234,
        file_descriptors: nil,
        enable_ssh: false,
        state: app_model.desired_state,
        diego: true,
        health_check_type: 'port'
      }

      VCAP::CloudController::ProcessModel.db[:processes].insert(process_hash)
    end

    it 'sets the file_descriptors value to the capi-release default' do
      process = VCAP::CloudController::ProcessModel.first(guid: app_model.guid).reload
      expect(process.file_descriptors).to be_nil
      Sequel::Migrator.run(VCAP::CloudController::AppModel.db, tmp_migrations_dir, table: :my_fake_table)

      process.reload
      expect(process.memory).to eq(117)
      expect(process.disk_quota).to eq(1234)
      expect(process.file_descriptors).to eq(16384)

      # ProcessModel redefines enable_ssh to point to its parent AppModel
      # To view what we set this to we need to fetch the value directly from the database
      process_record = VCAP::CloudController::ProcessModel.db[:processes].where(guid: app_model.guid).first
      expect(process_record[:enable_ssh]).to eq(false)
    end
  end

  context 'when a process has a null value for enable_ssh' do
    let(:app_model) { VCAP::CloudController::AppModel.make }
    before do
      process_hash = {
        guid: app_model.guid,
        app_guid: app_model.guid,
        type: 'web',
        instances: 0,
        memory: 117,
        disk_quota: 1234,
        file_descriptors: 9000,
        enable_ssh: nil,
        state: app_model.desired_state,
        diego: true,
        health_check_type: 'port'
      }

      VCAP::CloudController::ProcessModel.db[:processes].insert(process_hash)
    end

    it 'sets the enable_ssh value to the database default' do
      process = VCAP::CloudController::ProcessModel.first(guid: app_model.guid).reload

      # ProcessModel redefines enable_ssh to point to its parent AppModel
      # To view what we set this to we need to fetch the value directly from the database
      process_record = VCAP::CloudController::ProcessModel.db[:processes].where(guid: app_model.guid).first
      expect(process_record[:enable_ssh]).to be_nil

      Sequel::Migrator.run(VCAP::CloudController::AppModel.db, tmp_migrations_dir, table: :my_fake_table)

      process.reload
      expect(process.memory).to eq(117)
      expect(process.disk_quota).to eq(1234)
      expect(process.file_descriptors).to eq(9000)

      # ProcessModel redefines enable_ssh to point to its parent AppModel
      # To view what we set this to we need to fetch the value directly from the database
      process_record = VCAP::CloudController::ProcessModel.db[:processes].where(guid: app_model.guid).first
      expect(process_record[:enable_ssh]).to eq(false)
    end
  end
end
