require 'spec_helper'

RSpec.describe 'migration to add unique index on service_instance_id to service_instance_operations', isolation: :truncation do
  let(:filename) { '20220818142407_add_unique_index_to_service_instance_operations_service_instance_id.rb' }
  let(:tmp_migrations_dir) { Dir.mktmpdir }
  let(:db) { Sequel::Model.db }
  let(:service_instance) { VCAP::CloudController::ServiceInstance.make }

  before do
    FileUtils.cp(File.join(DBMigrator::SEQUEL_MIGRATIONS, filename), tmp_migrations_dir)

    # Override the 'allow_manual_update' option of 'Sequel::Plugins::Timestamps' for 'ServiceInstanceOperation'.
    VCAP::CloudController::ServiceInstanceOperation.instance_exec do
      @allow_manual_timestamp_update = true
    end

    # Revert the given migration, i.e. remove the uniqueness constraint.
    Sequel::Migrator.run(db, tmp_migrations_dir, target: 0, allow_missing_migration_files: true)
  end

  it 'removes duplicate service instance operations' do
    # Two operations that do not reference a service instance (i.e. service_instance_id is nil);
    # none of them should be removed.
    VCAP::CloudController::ServiceInstanceOperation.make
    VCAP::CloudController::ServiceInstanceOperation.make

    # Two operations that each reference a different service instance (the 'normal' situation);
    # none of them should be removed.
    si1 = VCAP::CloudController::ServiceInstance.make
    VCAP::CloudController::ServiceInstanceOperation.make(service_instance_id: si1.id)
    si2 = VCAP::CloudController::ServiceInstance.make
    VCAP::CloudController::ServiceInstanceOperation.make(service_instance_id: si2.id)

    # Three operations that reference the same service instance and have the same 'updated_at' value;
    # the one with the highest 'id' should be kept (o3).
    si3 = VCAP::CloudController::ServiceInstance.make
    o1 = VCAP::CloudController::ServiceInstanceOperation.make(service_instance_id: si3.id)
    o2 = VCAP::CloudController::ServiceInstanceOperation.make(service_instance_id: si3.id)
    o3 = VCAP::CloudController::ServiceInstanceOperation.make(service_instance_id: si3.id)
    o2.update({ updated_at: o1.updated_at })
    o3.update({ updated_at: o1.updated_at })

    # Three operations that reference the same service instance and have different 'updated_at' values;
    # the one with the newest 'updated_at' value should be kept (o5).
    si4 = VCAP::CloudController::ServiceInstance.make
    o4 = VCAP::CloudController::ServiceInstanceOperation.make(service_instance_id: si4.id)
    o5 = VCAP::CloudController::ServiceInstanceOperation.make(service_instance_id: si4.id)
    o6 = VCAP::CloudController::ServiceInstanceOperation.make(service_instance_id: si4.id)
    o5.update({ updated_at: o4.updated_at + 1 })
    o6.update({ updated_at: o4.updated_at - 1 })

    expect(VCAP::CloudController::ServiceInstanceOperation.count).to eq(10)

    Sequel::Migrator.run(db, tmp_migrations_dir, allow_missing_migration_files: true)

    expect(VCAP::CloudController::ServiceInstanceOperation.count).to eq(6)
    expect { o1.reload }.to raise_error(Sequel::NoExistingObject)
    expect { o2.reload }.to raise_error(Sequel::NoExistingObject)
    expect { o4.reload }.to raise_error(Sequel::NoExistingObject)
    expect { o6.reload }.to raise_error(Sequel::NoExistingObject)
  end
end
