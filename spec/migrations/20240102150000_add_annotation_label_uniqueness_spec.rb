require 'spec_helper'
require 'migrations/helpers/migration_shared_context'
RSpec.describe 'migration to add unique constraint to annotation and labels', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20240102150000_add_annotation_label_uniqueness.rb' }
  end

  let(:iso_segs) { db[:isolation_segments] }
  let(:annotations) { db[:isolation_segment_annotations] }
  let(:labels) { db[:isolation_segment_labels] }

  def insert_segment(name)
    guid = SecureRandom.uuid
    now = Time.now.utc
    iso_segs.insert(guid: guid, name: name, created_at: now, updated_at: now)
    guid
  end

  def insert_metadata(dataset, resource_guid, key_name:, value:, key_prefix: '')
    now = Time.now.utc
    dataset.insert(guid: SecureRandom.uuid, resource_guid: resource_guid,
                   key_prefix: key_prefix, key_name: key_name, value: value,
                   created_at: now, updated_at: now)
  end

  def insert_annotation(resource_guid, key_name:, value:, key_prefix: '')
    insert_metadata(annotations, resource_guid, key_name: key_name, value: value, key_prefix: key_prefix)
  end

  def insert_label(resource_guid, key_name:, value:, key_prefix: '')
    insert_metadata(labels, resource_guid, key_name: key_name, value: value, key_prefix: key_prefix)
  end

  def exists?(table, id)
    db[table].where(id: id).any?
  end

  describe 'annotation tables' do
    it 'handles key truncation, duplicate removal, and uniqueness constraints' do
      seg1_guid = insert_segment('bommel')
      key_name_long = 'a' * 64
      truncated_key_name = 'a' * 63
      key_name_short = 'b' * 63
      trunc_a1_id = insert_annotation(seg1_guid, key_name: key_name_long, value: 'some_value')
      trunc_a2_id = insert_annotation(seg1_guid, key_name: key_name_short, value: 'some_value2')

      seg2_guid = insert_segment('duplicate_test')
      key_c = 'c' * 63

      dup_a1_id = insert_annotation(seg2_guid, key_name: key_c, value: 'v1')
      dup_a2_id = insert_annotation(seg2_guid, key_name: key_c, value: 'v2')
      dup_a3_id = insert_annotation(seg2_guid, key_name: key_c, value: 'v3')

      dup_b1_id = insert_annotation(seg2_guid, key_name: key_c, value: 'v1', key_prefix: 'bommel')
      dup_b2_id = insert_annotation(seg2_guid, key_name: key_c, value: 'v2', key_prefix: 'bommel')
      dup_b3_id = insert_annotation(seg2_guid, key_name: key_c, value: 'v3', key_prefix: 'bommel')

      expect(dup_a1_id).to be < dup_a2_id
      expect(dup_a1_id).to be < dup_a3_id
      expect(dup_b1_id).to be < dup_b2_id
      expect(dup_b1_id).to be < dup_b3_id

      seg3_guid = insert_segment('sword')
      key_d = 'd' * 63
      key_e = 'e' * 63

      pres_a1_id = insert_annotation(seg1_guid, key_name: key_d, value: 'v1')
      pres_a2_id = insert_annotation(seg3_guid, key_name: key_d, value: 'v2')
      pres_a3_id = insert_annotation(seg1_guid, key_name: key_e, value: 'v3')

      pres_b1_id = insert_annotation(seg1_guid, key_name: key_d, value: 'v1', key_prefix: 'prefix1')
      pres_b2_id = insert_annotation(seg3_guid, key_name: key_d, value: 'v2', key_prefix: 'prefix1')
      pres_b3_id = insert_annotation(seg1_guid, key_name: key_e, value: 'v3', key_prefix: 'prefix1')
      pres_b4_id = insert_annotation(seg1_guid, key_name: key_d, value: 'v4', key_prefix: 'prefix2')

      seg4_guid = insert_segment('unique_test')
      seg5_guid = insert_segment('unique_test2')
      key_f = 'f' * 63
      key_g = 'g' * 63

      insert_annotation(seg4_guid, key_name: key_f, value: 'v1')
      insert_annotation(seg5_guid, key_name: key_f, value: 'v1', key_prefix: 'unique_prefix')

      # Run migration once
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

      # Verify truncation behavior
      expect(annotations.where(id: trunc_a1_id).get(:key_name)).to eq(truncated_key_name)
      expect(annotations.where(id: trunc_a2_id).get(:key_name)).to eq(key_name_short)

      # Verify duplicate removal (keeps smallest id)
      expect(annotations.where(resource_guid: seg2_guid, key_name: key_c).count).to eq(2)
      expect(exists?(:isolation_segment_annotations, dup_a1_id)).to be true
      expect(exists?(:isolation_segment_annotations, dup_a2_id)).to be false
      expect(exists?(:isolation_segment_annotations, dup_a3_id)).to be false
      expect(exists?(:isolation_segment_annotations, dup_b1_id)).to be true
      expect(exists?(:isolation_segment_annotations, dup_b2_id)).to be false
      expect(exists?(:isolation_segment_annotations, dup_b3_id)).to be false

      # Verify preservation of records with different columns
      expect(exists?(:isolation_segment_annotations, pres_a1_id)).to be true
      expect(exists?(:isolation_segment_annotations, pres_a2_id)).to be true
      expect(exists?(:isolation_segment_annotations, pres_a3_id)).to be true
      expect(exists?(:isolation_segment_annotations, pres_b1_id)).to be true
      expect(exists?(:isolation_segment_annotations, pres_b2_id)).to be true
      expect(exists?(:isolation_segment_annotations, pres_b3_id)).to be true
      expect(exists?(:isolation_segment_annotations, pres_b4_id)).to be true

      # Verify uniqueness constraints: does not allow adding a duplicate
      expect { insert_annotation(seg4_guid, key_name: key_f, value: 'v2') }.to raise_error(Sequel::UniqueConstraintViolation)
      expect { insert_annotation(seg5_guid, key_name: key_f, value: 'v2', key_prefix: 'unique_prefix') }.to raise_error(Sequel::UniqueConstraintViolation)

      # Verify uniqueness constraints: does allow adding different annotations
      uniq_a1_id = insert_annotation(seg4_guid, key_name: key_g, value: 'v3')
      uniq_a2_id = insert_annotation(seg5_guid, key_name: key_g, value: 'v2')
      uniq_b1_id = insert_annotation(seg4_guid, key_name: key_f, value: 'v4', key_prefix: 'other_prefix')
      uniq_b2_id = insert_annotation(seg5_guid, key_name: key_f, value: 'v5', key_prefix: 'other_prefix')
      expect(annotations.where(key_name: key_g).count).to eq(2)
      expect(exists?(:isolation_segment_annotations, uniq_a1_id)).to be true
      expect(exists?(:isolation_segment_annotations, uniq_a2_id)).to be true
      expect(exists?(:isolation_segment_annotations, uniq_b1_id)).to be true
      expect(exists?(:isolation_segment_annotations, uniq_b2_id)).to be true
    end
  end

  describe 'labels tables' do
    it 'handles duplicate removal and uniqueness constraints' do
      seg1_guid = insert_segment('label_dup_test')
      key_a = 'a' * 63

      dup_a1_id = insert_label(seg1_guid, key_name: key_a, value: 'v1')
      dup_a2_id = insert_label(seg1_guid, key_name: key_a, value: 'v2')
      dup_a3_id = insert_label(seg1_guid, key_name: key_a, value: 'v3')

      dup_b1_id = insert_label(seg1_guid, key_name: key_a, value: 'v1', key_prefix: 'bommel')
      dup_b2_id = insert_label(seg1_guid, key_name: key_a, value: 'v2', key_prefix: 'bommel')
      dup_b3_id = insert_label(seg1_guid, key_name: key_a, value: 'v3', key_prefix: 'bommel')

      expect(dup_a1_id).to be < dup_a2_id
      expect(dup_a1_id).to be < dup_a3_id
      expect(dup_b1_id).to be < dup_b2_id
      expect(dup_b1_id).to be < dup_b3_id

      seg2_guid = insert_segment('label_preserve_test')
      key_b = 'b' * 63
      key_c = 'c' * 63

      pres_a1_id = insert_label(seg1_guid, key_name: key_b, value: 'v1')
      pres_a2_id = insert_label(seg2_guid, key_name: key_b, value: 'v2')
      pres_a3_id = insert_label(seg1_guid, key_name: key_c, value: 'v3')

      pres_b1_id = insert_label(seg1_guid, key_name: key_b, value: 'v1', key_prefix: 'prefix1')
      pres_b2_id = insert_label(seg2_guid, key_name: key_b, value: 'v2', key_prefix: 'prefix1')
      pres_b3_id = insert_label(seg1_guid, key_name: key_c, value: 'v3', key_prefix: 'prefix1')
      pres_b4_id = insert_label(seg1_guid, key_name: key_b, value: 'v4', key_prefix: 'prefix2')

      seg3_guid = insert_segment('label_unique_test')
      seg4_guid = insert_segment('label_unique_test2')
      key_d = 'd' * 63
      key_e = 'e' * 63

      insert_label(seg3_guid, key_name: key_d, value: 'v1')
      insert_label(seg4_guid, key_name: key_d, value: 'v1', key_prefix: 'unique_prefix')

      # Run migration once
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

      # Verify duplicate removal (keeps smallest id)
      expect(labels.where(resource_guid: seg1_guid, key_name: key_a).count).to eq(2)
      expect(exists?(:isolation_segment_labels, dup_a1_id)).to be true
      expect(exists?(:isolation_segment_labels, dup_a2_id)).to be false
      expect(exists?(:isolation_segment_labels, dup_a3_id)).to be false
      expect(exists?(:isolation_segment_labels, dup_b1_id)).to be true
      expect(exists?(:isolation_segment_labels, dup_b2_id)).to be false
      expect(exists?(:isolation_segment_labels, dup_b3_id)).to be false

      # Verify preservation of records with different columns
      expect(exists?(:isolation_segment_labels, pres_a1_id)).to be true
      expect(exists?(:isolation_segment_labels, pres_a2_id)).to be true
      expect(exists?(:isolation_segment_labels, pres_a3_id)).to be true
      expect(exists?(:isolation_segment_labels, pres_b1_id)).to be true
      expect(exists?(:isolation_segment_labels, pres_b2_id)).to be true
      expect(exists?(:isolation_segment_labels, pres_b3_id)).to be true
      expect(exists?(:isolation_segment_labels, pres_b4_id)).to be true

      # Verify uniqueness constraints: does not allow adding a duplicate
      expect { insert_label(seg3_guid, key_name: key_d, value: 'v2') }.to raise_error(Sequel::UniqueConstraintViolation)
      expect { insert_label(seg4_guid, key_name: key_d, value: 'v2', key_prefix: 'unique_prefix') }.to raise_error(Sequel::UniqueConstraintViolation)

      # Verify uniqueness constraints: does allow adding different labels
      uniq_a1_id = insert_label(seg3_guid, key_name: key_e, value: 'v3')
      uniq_a2_id = insert_label(seg4_guid, key_name: key_e, value: 'v2')
      uniq_b1_id = insert_label(seg3_guid, key_name: key_d, value: 'v4', key_prefix: 'other_prefix')
      uniq_b2_id = insert_label(seg4_guid, key_name: key_d, value: 'v5', key_prefix: 'other_prefix')
      expect(labels.where(key_name: key_e).count).to eq(2)
      expect(exists?(:isolation_segment_labels, uniq_a1_id)).to be true
      expect(exists?(:isolation_segment_labels, uniq_a2_id)).to be true
      expect(exists?(:isolation_segment_labels, uniq_b1_id)).to be true
      expect(exists?(:isolation_segment_labels, uniq_b2_id)).to be true
    end
  end
end
