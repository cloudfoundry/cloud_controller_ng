require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add unique constraint to annotation and labels', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20240102150000_add_annotation_label_uniqueness.rb' }
  end

  let(:isolation_segment) { VCAP::CloudController::IsolationSegmentModel }
  let(:annotation) { VCAP::CloudController::IsolationSegmentAnnotationModel }
  let(:label) { VCAP::CloudController::IsolationSegmentLabelModel }

  describe 'annotation tables' do
    it 'truncates keys to 63 characters' do
      i1 = isolation_segment.create(name: 'bommel')
      key_name = 'a' * 64
      truncated_key_name = 'a' * 63

      a1 = annotation.create(resource_guid: i1.guid, key_name: key_name, value: 'some_value')

      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(a1.reload.key_name).to eq(truncated_key_name)
    end

    it 'leaves keys that are shorter than 64 characters unchanged' do
      i1 = isolation_segment.create(name: 'bommel')
      key_name = 'a' * 63

      a1 = annotation.create(resource_guid: i1.guid, key_name: key_name, value: 'some_value')

      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(a1.reload.key_name).to eq(key_name)
    end

    it 'removes duplicate annotations but keeps one with smallest id' do
      i1 = isolation_segment.create(name: 'bommel')
      key_name = 'a' * 63

      # In case key_prefix is not set
      a1 = annotation.create(resource_guid: i1.guid, key_name: key_name, value: 'v1')
      a2 = annotation.create(resource_guid: i1.guid, key_name: key_name, value: 'v2')
      a3 = annotation.create(resource_guid: i1.guid, key_name: key_name, value: 'v3')
      # In case key_prefix is set
      b1 = annotation.create(resource_guid: i1.guid, key_prefix: 'bommel', key_name: key_name, value: 'v1')
      b2 = annotation.create(resource_guid: i1.guid, key_prefix: 'bommel', key_name: key_name, value: 'v2')
      b3 = annotation.create(resource_guid: i1.guid, key_prefix: 'bommel', key_name: key_name, value: 'v3')

      expect(a1.id).to be < a2.id
      expect(a1.id).to be < a3.id
      expect(b1.id).to be < b2.id
      expect(b1.id).to be < b3.id

      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(annotation.where(key_name:).count).to eq(2)
      expect(a1.reload).to be_a(annotation)
      expect { a2.reload }.to raise_error(Sequel::NoExistingObject)
      expect { a3.reload }.to raise_error(Sequel::NoExistingObject)
      expect(b1.reload).to be_a(annotation)
      expect { b2.reload }.to raise_error(Sequel::NoExistingObject)
      expect { b3.reload }.to raise_error(Sequel::NoExistingObject)
    end

    it 'does not remove records if any column of key, key_prefix or resource_guid is different' do
      i1 = isolation_segment.create(name: 'bommel')
      i2 = isolation_segment.create(name: 'sword')
      key_a = 'a' * 63
      key_b = 'b' * 63

      # In case key_prefix is not set
      a1 = annotation.create(resource_guid: i1.guid, key_name: key_a, value: 'v1')
      a2 = annotation.create(resource_guid: i2.guid, key_name: key_a, value: 'v2')
      a3 = annotation.create(resource_guid: i1.guid, key_name: key_b, value: 'v3')
      # In case key_prefix is set
      b1 = annotation.create(resource_guid: i1.guid, key_prefix: 'bommel', key_name: key_a, value: 'v1')
      b2 = annotation.create(resource_guid: i2.guid, key_prefix: 'bommel', key_name: key_a, value: 'v2')
      b3 = annotation.create(resource_guid: i1.guid, key_prefix: 'bommel', key_name: key_b, value: 'v3')
      b4 = annotation.create(resource_guid: i1.guid, key_prefix: 'sword', key_name: key_a, value: 'v4')

      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

      expect(annotation.all.count).to eq(7)
      expect(a1.reload).to be_a(annotation)
      expect(a2.reload).to be_a(annotation)
      expect(a3.reload).to be_a(annotation)
      expect(b1.reload).to be_a(annotation)
      expect(b2.reload).to be_a(annotation)
      expect(b3.reload).to be_a(annotation)
      expect(b4.reload).to be_a(annotation)
    end

    it 'does not allow adding a duplicate' do
      i1 = isolation_segment.create(name: 'bommel')
      i2 = isolation_segment.create(name: 'sword')
      key = 'a' * 63

      # In case key_prefix is not set
      annotation.create(resource_guid: i1.guid, key_name: key, value: 'v1')
      # In case key_prefix is set
      annotation.create(resource_guid: i2.guid, key_prefix: 'bommel', key_name: key, value: 'v1')

      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

      expect { annotation.create(resource_guid: i1.guid, key_name: key, value: 'v2') }.to raise_error(Sequel::UniqueConstraintViolation)
      expect { annotation.create(resource_guid: i2.guid, key_prefix: 'bommel', key_name: key, value: 'v2') }.to raise_error(Sequel::UniqueConstraintViolation)
    end

    it 'does allow adding a different annotation' do
      i1 = isolation_segment.create(name: 'bommel')
      i2 = isolation_segment.create(name: 'sword')
      key_a = 'a' * 63
      key_b = 'b' * 63

      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

      # In case key_prefix is not set
      a1 = annotation.create(resource_guid: i1.guid, key_name: key_a, value: 'v1')
      a2 = annotation.create(resource_guid: i2.guid, key_name: key_a, value: 'v2')
      a3 = annotation.create(resource_guid: i1.guid, key_name: key_b, value: 'v3')
      # In case key_prefix is set
      b1 = annotation.create(resource_guid: i1.guid, key_prefix: 'bommel', key_name: key_a, value: 'v1')
      b2 = annotation.create(resource_guid: i2.guid, key_prefix: 'bommel', key_name: key_a, value: 'v2')
      b3 = annotation.create(resource_guid: i1.guid, key_prefix: 'bommel', key_name: key_b, value: 'v3')
      b4 = annotation.create(resource_guid: i1.guid, key_prefix: 'sword', key_name: key_a, value: 'v4')

      expect(annotation.all.count).to eq(7)
      expect(a1.reload).to be_a(annotation)
      expect(a2.reload).to be_a(annotation)
      expect(a3.reload).to be_a(annotation)
      expect(b1.reload).to be_a(annotation)
      expect(b2.reload).to be_a(annotation)
      expect(b3.reload).to be_a(annotation)
      expect(b4.reload).to be_a(annotation)
    end
  end

  describe 'labels tables' do
    it 'removes duplicate annotations but keeps one with smallest id' do
      i1 = isolation_segment.create(name: 'bommel')
      key = 'a' * 63

      # In case key_prefix is not set
      a1 = label.create(resource_guid: i1.guid, key_name: key, value: 'v1')
      a2 = label.create(resource_guid: i1.guid, key_name: key, value: 'v2')
      a3 = label.create(resource_guid: i1.guid, key_name: key, value: 'v3')
      # In case key_prefix is set
      b1 = label.create(resource_guid: i1.guid, key_prefix: 'bommel', key_name: key, value: 'v1')
      b2 = label.create(resource_guid: i1.guid, key_prefix: 'bommel', key_name: key, value: 'v2')
      b3 = label.create(resource_guid: i1.guid, key_prefix: 'bommel', key_name: key, value: 'v3')

      expect(a1.id).to be < a2.id
      expect(a1.id).to be < a3.id
      expect(b1.id).to be < b2.id
      expect(b1.id).to be < b3.id

      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(label.where(key_name: key).count).to eq(2)
      expect(a1.reload).to be_a(label)
      expect { a2.reload }.to raise_error(Sequel::NoExistingObject)
      expect { a3.reload }.to raise_error(Sequel::NoExistingObject)
      expect(b1.reload).to be_a(label)
      expect { b2.reload }.to raise_error(Sequel::NoExistingObject)
      expect { b3.reload }.to raise_error(Sequel::NoExistingObject)
    end

    it 'does not remove records if any column of key_name, key_prefix or resource_guid is different' do
      i1 = isolation_segment.create(name: 'bommel')
      i2 = isolation_segment.create(name: 'sword')
      key_a = 'a' * 63
      key_b = 'b' * 63

      # In case key_prefix is not set
      a1 = label.create(resource_guid: i1.guid, key_name: key_a, value: 'v1')
      a2 = label.create(resource_guid: i2.guid, key_name: key_a, value: 'v2')
      a3 = label.create(resource_guid: i1.guid, key_name: key_b, value: 'v3')
      # In case key_prefix is set
      b1 = label.create(resource_guid: i1.guid, key_prefix: 'bommel', key_name: key_a, value: 'v1')
      b2 = label.create(resource_guid: i2.guid, key_prefix: 'bommel', key_name: key_a, value: 'v2')
      b3 = label.create(resource_guid: i1.guid, key_prefix: 'bommel', key_name: key_b, value: 'v3')
      b4 = label.create(resource_guid: i1.guid, key_prefix: 'sword', key_name: key_a, value: 'v4')

      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

      expect(label.all.count).to eq(7)
      expect(a1.reload).to be_a(label)
      expect(a2.reload).to be_a(label)
      expect(a3.reload).to be_a(label)
      expect(b1.reload).to be_a(label)
      expect(b2.reload).to be_a(label)
      expect(b3.reload).to be_a(label)
      expect(b4.reload).to be_a(label)
    end

    it 'does not allow adding a duplicate' do
      i1 = isolation_segment.create(name: 'bommel')
      i2 = isolation_segment.create(name: 'sword')
      key = 'a' * 63

      # In case key_prefix is not set
      label.create(resource_guid: i1.guid, key_name: key, value: 'v1')
      # In case key_prefix is set
      label.create(resource_guid: i2.guid, key_prefix: 'bommel', key_name: key, value: 'v1')

      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

      expect { label.create(resource_guid: i1.guid, key_name: key, value: 'v2') }.to raise_error(Sequel::UniqueConstraintViolation)
      expect { label.create(resource_guid: i2.guid, key_prefix: 'bommel', key_name: key, value: 'v2') }.to raise_error(Sequel::UniqueConstraintViolation)
    end

    it 'does allow adding a different label' do
      i1 = isolation_segment.create(name: 'bommel')
      i2 = isolation_segment.create(name: 'sword')
      key_a = 'a' * 63
      key_b = 'b' * 63

      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

      # In case key_prefix is not set
      a1 = label.create(resource_guid: i1.guid, key_name: key_a, value: 'v1')
      a2 = label.create(resource_guid: i2.guid, key_name: key_a, value: 'v2')
      a3 = label.create(resource_guid: i1.guid, key_name: key_b, value: 'v3')
      # In case key_prefix is set
      b1 = label.create(resource_guid: i1.guid, key_prefix: 'bommel', key_name: key_a, value: 'v1')
      b2 = label.create(resource_guid: i2.guid, key_prefix: 'bommel', key_name: key_a, value: 'v2')
      b3 = label.create(resource_guid: i1.guid, key_prefix: 'bommel', key_name: key_b, value: 'v3')
      b4 = label.create(resource_guid: i1.guid, key_prefix: 'sword', key_name: key_a, value: 'v4')

      expect(label.all.count).to eq(7)
      expect(a1.reload).to be_a(label)
      expect(a2.reload).to be_a(label)
      expect(a3.reload).to be_a(label)
      expect(b1.reload).to be_a(label)
      expect(b2.reload).to be_a(label)
      expect(b3.reload).to be_a(label)
      expect(b4.reload).to be_a(label)
    end
  end
end
