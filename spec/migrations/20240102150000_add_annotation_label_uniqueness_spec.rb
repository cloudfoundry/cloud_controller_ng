require 'spec_helper'
require 'migrations/helpers/migration_shared_context'
RSpec.describe 'migration to add unique constraint to annotation and labels', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20240102150000_add_annotation_label_uniqueness.rb' }
  end
  let(:isolation_segment) { VCAP::CloudController::IsolationSegmentModel }
  let(:annotation) { VCAP::CloudController::IsolationSegmentAnnotationModel }
  let(:label) { VCAP::CloudController::IsolationSegmentLabelModel }

  describe 'annotation and label tables' do
    it 'handles key truncation, duplicate removal, and uniqueness constraints' do
      # Setup data for truncation test
      i1 = isolation_segment.create(name: 'bommel')
      key_name_long = 'a' * 64
      truncated_key_name = 'a' * 63
      key_name_short = 'b' * 63
      trunc_a1 = annotation.create(resource_guid: i1.guid, key_name: key_name_long, value: 'some_value')
      trunc_a2 = annotation.create(resource_guid: i1.guid, key_name: key_name_short, value: 'some_value2')

      # Setup data for duplicate removal test
      i2 = isolation_segment.create(name: 'duplicate_test')
      key_c = 'c' * 63

      # In case key_prefix is not set
      dup_a1 = annotation.create(resource_guid: i2.guid, key_name: key_c, value: 'v1')
      dup_a2 = annotation.create(resource_guid: i2.guid, key_name: key_c, value: 'v2')
      dup_a3 = annotation.create(resource_guid: i2.guid, key_name: key_c, value: 'v3')

      # In case key_prefix is set
      dup_b1 = annotation.create(resource_guid: i2.guid, key_prefix: 'bommel', key_name: key_c, value: 'v1')
      dup_b2 = annotation.create(resource_guid: i2.guid, key_prefix: 'bommel', key_name: key_c, value: 'v2')
      dup_b3 = annotation.create(resource_guid: i2.guid, key_prefix: 'bommel', key_name: key_c, value: 'v3')

      expect(dup_a1.id).to be < dup_a2.id
      expect(dup_a1.id).to be < dup_a3.id
      expect(dup_b1.id).to be < dup_b2.id
      expect(dup_b1.id).to be < dup_b3.id

      # Setup data for preservation test (different columns)
      i3 = isolation_segment.create(name: 'sword')
      key_d = 'd' * 63
      key_e = 'e' * 63

      # In case key_prefix is not set
      pres_a1 = annotation.create(resource_guid: i1.guid, key_name: key_d, value: 'v1')
      pres_a2 = annotation.create(resource_guid: i3.guid, key_name: key_d, value: 'v2')
      pres_a3 = annotation.create(resource_guid: i1.guid, key_name: key_e, value: 'v3')

      # In case key_prefix is set
      pres_b1 = annotation.create(resource_guid: i1.guid, key_prefix: 'prefix1', key_name: key_d, value: 'v1')
      pres_b2 = annotation.create(resource_guid: i3.guid, key_prefix: 'prefix1', key_name: key_d, value: 'v2')
      pres_b3 = annotation.create(resource_guid: i1.guid, key_prefix: 'prefix1', key_name: key_e, value: 'v3')
      pres_b4 = annotation.create(resource_guid: i1.guid, key_prefix: 'prefix2', key_name: key_d, value: 'v4')

      # Setup data for uniqueness constraint test
      i4 = isolation_segment.create(name: 'unique_test')
      i5 = isolation_segment.create(name: 'unique_test2')
      key_f = 'f' * 63
      key_g = 'g' * 63

      # In case key_prefix is not set
      annotation.create(resource_guid: i4.guid, key_name: key_f, value: 'v1')

      # In case key_prefix is set
      annotation.create(resource_guid: i5.guid, key_prefix: 'unique_prefix', key_name: key_f, value: 'v1')

      # Setup label data for duplicate removal test
      label_i1 = isolation_segment.create(name: 'label_dup_test')
      label_key_a = 'a' * 63

      # In case key_prefix is not set
      label_dup_a1 = label.create(resource_guid: label_i1.guid, key_name: label_key_a, value: 'v1')
      label_dup_a2 = label.create(resource_guid: label_i1.guid, key_name: label_key_a, value: 'v2')
      label_dup_a3 = label.create(resource_guid: label_i1.guid, key_name: label_key_a, value: 'v3')

      # In case key_prefix is set
      label_dup_b1 = label.create(resource_guid: label_i1.guid, key_prefix: 'bommel', key_name: label_key_a, value: 'v1')
      label_dup_b2 = label.create(resource_guid: label_i1.guid, key_prefix: 'bommel', key_name: label_key_a, value: 'v2')
      label_dup_b3 = label.create(resource_guid: label_i1.guid, key_prefix: 'bommel', key_name: label_key_a, value: 'v3')
      expect(label_dup_a1.id).to be < label_dup_a2.id
      expect(label_dup_a1.id).to be < label_dup_a3.id
      expect(label_dup_b1.id).to be < label_dup_b2.id
      expect(label_dup_b1.id).to be < label_dup_b3.id

      # Setup label data for preservation test (different columns)
      label_i2 = isolation_segment.create(name: 'label_preserve_test')
      label_key_b = 'b' * 63
      label_key_c = 'c' * 63

      # In case key_prefix is not set
      label_pres_a1 = label.create(resource_guid: label_i1.guid, key_name: label_key_b, value: 'v1')
      label_pres_a2 = label.create(resource_guid: label_i2.guid, key_name: label_key_b, value: 'v2')
      label_pres_a3 = label.create(resource_guid: label_i1.guid, key_name: label_key_c, value: 'v3')

      # In case key_prefix is set
      label_pres_b1 = label.create(resource_guid: label_i1.guid, key_prefix: 'prefix1', key_name: label_key_b, value: 'v1')
      label_pres_b2 = label.create(resource_guid: label_i2.guid, key_prefix: 'prefix1', key_name: label_key_b, value: 'v2')
      label_pres_b3 = label.create(resource_guid: label_i1.guid, key_prefix: 'prefix1', key_name: label_key_c, value: 'v3')
      label_pres_b4 = label.create(resource_guid: label_i1.guid, key_prefix: 'prefix2', key_name: label_key_b, value: 'v4')

      # Setup label data for uniqueness constraint test
      label_i3 = isolation_segment.create(name: 'label_unique_test')
      label_i4 = isolation_segment.create(name: 'label_unique_test2')
      label_key_d = 'd' * 63
      label_key_e = 'e' * 63

      # In case key_prefix is not set
      label.create(resource_guid: label_i3.guid, key_name: label_key_d, value: 'v1')

      # In case key_prefix is set
      label.create(resource_guid: label_i4.guid, key_prefix: 'unique_prefix', key_name: label_key_d, value: 'v1')

      # Run migration once
      expect { run_migration }.not_to raise_error

      # Verify truncation behavior
      expect(trunc_a1.reload.key_name).to eq(truncated_key_name)
      expect(trunc_a2.reload.key_name).to eq(key_name_short)

      # Verify duplicate removal (keeps smallest id)
      expect(annotation.where(resource_guid: i2.guid, key_name: key_c).count).to eq(2)
      expect(dup_a1.reload).to be_a(annotation)
      expect { dup_a2.reload }.to raise_error(Sequel::NoExistingObject)
      expect { dup_a3.reload }.to raise_error(Sequel::NoExistingObject)
      expect(dup_b1.reload).to be_a(annotation)
      expect { dup_b2.reload }.to raise_error(Sequel::NoExistingObject)
      expect { dup_b3.reload }.to raise_error(Sequel::NoExistingObject)

      # Verify preservation of records with different columns
      expect([pres_a1, pres_a2, pres_a3, pres_b1, pres_b2, pres_b3, pres_b4].map(&:reload)).to all(be_a(annotation))

      # Verify uniqueness constraints: does not allow adding a duplicate
      expect { annotation.create(resource_guid: i4.guid, key_name: key_f, value: 'v2') }.to raise_error(Sequel::UniqueConstraintViolation)
      expect { annotation.create(resource_guid: i5.guid, key_prefix: 'unique_prefix', key_name: key_f, value: 'v2') }.to raise_error(Sequel::UniqueConstraintViolation)

      # Verify uniqueness constraints: does allow adding different annotations
      uniq_a1 = annotation.create(resource_guid: i4.guid, key_name: key_g, value: 'v3')
      uniq_a2 = annotation.create(resource_guid: i5.guid, key_name: key_g, value: 'v2')
      uniq_b1 = annotation.create(resource_guid: i4.guid, key_prefix: 'other_prefix', key_name: key_f, value: 'v4')
      uniq_b2 = annotation.create(resource_guid: i5.guid, key_prefix: 'other_prefix', key_name: key_f, value: 'v5')
      expect(annotation.where(key_name: key_g).count).to eq(2)
      expect([uniq_a1, uniq_a2, uniq_b1, uniq_b2].map(&:reload)).to all(be_a(annotation))

      # Verify label duplicate removal (keeps smallest id)
      expect(label.where(resource_guid: label_i1.guid, key_name: label_key_a).count).to eq(2)
      expect(label_dup_a1.reload).to be_a(label)
      expect { label_dup_a2.reload }.to raise_error(Sequel::NoExistingObject)
      expect { label_dup_a3.reload }.to raise_error(Sequel::NoExistingObject)
      expect(label_dup_b1.reload).to be_a(label)
      expect { label_dup_b2.reload }.to raise_error(Sequel::NoExistingObject)
      expect { label_dup_b3.reload }.to raise_error(Sequel::NoExistingObject)

      # Verify preservation of labels with different columns
      expect([label_pres_a1, label_pres_a2, label_pres_a3, label_pres_b1, label_pres_b2, label_pres_b3, label_pres_b4].map(&:reload)).to all(be_a(label))

      # Verify label uniqueness constraints: does not allow adding a duplicate
      expect { label.create(resource_guid: label_i3.guid, key_name: label_key_d, value: 'v2') }.to raise_error(Sequel::UniqueConstraintViolation)
      expect { label.create(resource_guid: label_i4.guid, key_prefix: 'unique_prefix', key_name: label_key_d, value: 'v2') }.to raise_error(Sequel::UniqueConstraintViolation)

      # Verify uniqueness constraints: does allow adding different labels
      label_uniq_a1 = label.create(resource_guid: label_i3.guid, key_name: label_key_e, value: 'v3')
      label_uniq_a2 = label.create(resource_guid: label_i4.guid, key_name: label_key_e, value: 'v2')
      label_uniq_b1 = label.create(resource_guid: label_i3.guid, key_prefix: 'other_prefix', key_name: label_key_d, value: 'v4')
      label_uniq_b2 = label.create(resource_guid: label_i4.guid, key_prefix: 'other_prefix', key_name: label_key_d, value: 'v5')
      expect(label.where(key_name: label_key_e).count).to eq(2)
      expect([label_uniq_a1, label_uniq_a2, label_uniq_b1, label_uniq_b2].map(&:reload)).to all(be_a(label))

      # Up migration idempotency - uniqueness constraint still enforced
      test_up_migration_idempotency
      expect { annotation.create(resource_guid: i4.guid, key_name: key_f, value: 'v6') }.to raise_error(Sequel::UniqueConstraintViolation)
      expect { label.create(resource_guid: label_i3.guid, key_name: label_key_d, value: 'v6') }.to raise_error(Sequel::UniqueConstraintViolation)

      # Down migration - uniqueness constraint removed, duplicates allowed again
      expect { revert_migration }.not_to raise_error
      expect { annotation.create(resource_guid: i4.guid, key_name: key_f, value: 'v7') }.not_to raise_error
      expect { label.create(resource_guid: label_i3.guid, key_name: label_key_d, value: 'v7') }.not_to raise_error

      # Down migration idempotency - constraint still absent
      test_down_migration_idempotency
      expect { annotation.create(resource_guid: i4.guid, key_name: key_f, value: 'v8') }.not_to raise_error
      expect { label.create(resource_guid: label_i3.guid, key_name: label_key_d, value: 'v8') }.not_to raise_error
    end
  end
end
