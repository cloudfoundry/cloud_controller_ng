require 'spec_helper'
require 'migrations/helpers/migration_shared_context'
RSpec.describe 'migration to add unique constraint to annotation and labels', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20240102150000_add_annotation_label_uniqueness.rb' }
  end
  let(:isolation_segment) { VCAP::CloudController::IsolationSegmentModel }
  let(:annotation) { VCAP::CloudController::IsolationSegmentAnnotationModel }
  let(:label) { VCAP::CloudController::IsolationSegmentLabelModel }

  # Two former examples (one for annotations, one for labels) consolidated
  # into a single it block. Each formerly ran an independent migration
  # rollback-and-forward cycle in migration_shared_context (~2.5s each).
  # Both setups operate on disjoint resource_guids, so they don't collide;
  # running them in one example halves the migration cycles for this file.
  # See spec/migrations/Readme.md.
  it 'truncates long annotation keys, removes duplicates, and adds uniqueness constraints (annotations + labels)' do # rubocop:disable RSpec/MultipleExpectations
    # === Annotations setup ===

    # Setup data for truncation test
    i1 = isolation_segment.create(name: 'bommel')
    key_name_long = 'a' * 64
    truncated_key_name = 'a' * 63
    key_name_short = 'b' * 63
    trunc_a1 = annotation.create(resource_guid: i1.guid, key_name: key_name_long, value: 'some_value')
    trunc_a2 = annotation.create(resource_guid: i1.guid, key_name: key_name_short, value: 'some_value2')

    # Setup data for duplicate removal test (annotations)
    i2 = isolation_segment.create(name: 'duplicate_test')
    key_c = 'c' * 63

    ann_dup_a1 = annotation.create(resource_guid: i2.guid, key_name: key_c, value: 'v1')
    ann_dup_a2 = annotation.create(resource_guid: i2.guid, key_name: key_c, value: 'v2')
    ann_dup_a3 = annotation.create(resource_guid: i2.guid, key_name: key_c, value: 'v3')

    ann_dup_b1 = annotation.create(resource_guid: i2.guid, key_prefix: 'bommel', key_name: key_c, value: 'v1')
    ann_dup_b2 = annotation.create(resource_guid: i2.guid, key_prefix: 'bommel', key_name: key_c, value: 'v2')
    ann_dup_b3 = annotation.create(resource_guid: i2.guid, key_prefix: 'bommel', key_name: key_c, value: 'v3')

    expect(ann_dup_a1.id).to be < ann_dup_a2.id
    expect(ann_dup_a1.id).to be < ann_dup_a3.id
    expect(ann_dup_b1.id).to be < ann_dup_b2.id
    expect(ann_dup_b1.id).to be < ann_dup_b3.id

    # Setup data for preservation test (annotations - different columns)
    i3 = isolation_segment.create(name: 'sword')
    key_d = 'd' * 63
    key_e = 'e' * 63

    ann_pres_a1 = annotation.create(resource_guid: i1.guid, key_name: key_d, value: 'v1')
    ann_pres_a2 = annotation.create(resource_guid: i3.guid, key_name: key_d, value: 'v2')
    ann_pres_a3 = annotation.create(resource_guid: i1.guid, key_name: key_e, value: 'v3')

    ann_pres_b1 = annotation.create(resource_guid: i1.guid, key_prefix: 'prefix1', key_name: key_d, value: 'v1')
    ann_pres_b2 = annotation.create(resource_guid: i3.guid, key_prefix: 'prefix1', key_name: key_d, value: 'v2')
    ann_pres_b3 = annotation.create(resource_guid: i1.guid, key_prefix: 'prefix1', key_name: key_e, value: 'v3')
    ann_pres_b4 = annotation.create(resource_guid: i1.guid, key_prefix: 'prefix2', key_name: key_d, value: 'v4')

    # Setup data for uniqueness constraint test (annotations)
    i4 = isolation_segment.create(name: 'unique_test')
    i5 = isolation_segment.create(name: 'unique_test2')
    key_f = 'f' * 63
    key_g = 'g' * 63

    annotation.create(resource_guid: i4.guid, key_name: key_f, value: 'v1')
    annotation.create(resource_guid: i5.guid, key_prefix: 'unique_prefix', key_name: key_f, value: 'v1')

    # === Labels setup ===

    # Setup data for duplicate removal test (labels)
    li1 = isolation_segment.create(name: 'label_dup_test')
    lkey_a = 'a' * 63

    lbl_dup_a1 = label.create(resource_guid: li1.guid, key_name: lkey_a, value: 'v1')
    lbl_dup_a2 = label.create(resource_guid: li1.guid, key_name: lkey_a, value: 'v2')
    lbl_dup_a3 = label.create(resource_guid: li1.guid, key_name: lkey_a, value: 'v3')

    lbl_dup_b1 = label.create(resource_guid: li1.guid, key_prefix: 'bommel', key_name: lkey_a, value: 'v1')
    lbl_dup_b2 = label.create(resource_guid: li1.guid, key_prefix: 'bommel', key_name: lkey_a, value: 'v2')
    lbl_dup_b3 = label.create(resource_guid: li1.guid, key_prefix: 'bommel', key_name: lkey_a, value: 'v3')
    expect(lbl_dup_a1.id).to be < lbl_dup_a2.id
    expect(lbl_dup_a1.id).to be < lbl_dup_a3.id
    expect(lbl_dup_b1.id).to be < lbl_dup_b2.id
    expect(lbl_dup_b1.id).to be < lbl_dup_b3.id

    # Setup data for preservation test (labels - different columns)
    li2 = isolation_segment.create(name: 'label_preserve_test')
    lkey_b = 'b' * 63
    lkey_c = 'c' * 63

    lbl_pres_a1 = label.create(resource_guid: li1.guid, key_name: lkey_b, value: 'v1')
    lbl_pres_a2 = label.create(resource_guid: li2.guid, key_name: lkey_b, value: 'v2')
    lbl_pres_a3 = label.create(resource_guid: li1.guid, key_name: lkey_c, value: 'v3')

    lbl_pres_b1 = label.create(resource_guid: li1.guid, key_prefix: 'prefix1', key_name: lkey_b, value: 'v1')
    lbl_pres_b2 = label.create(resource_guid: li2.guid, key_prefix: 'prefix1', key_name: lkey_b, value: 'v2')
    lbl_pres_b3 = label.create(resource_guid: li1.guid, key_prefix: 'prefix1', key_name: lkey_c, value: 'v3')
    lbl_pres_b4 = label.create(resource_guid: li1.guid, key_prefix: 'prefix2', key_name: lkey_b, value: 'v4')

    # Setup data for uniqueness constraint test (labels)
    li3 = isolation_segment.create(name: 'label_unique_test')
    li4 = isolation_segment.create(name: 'label_unique_test2')
    lkey_d = 'd' * 63
    lkey_e = 'e' * 63

    label.create(resource_guid: li3.guid, key_name: lkey_d, value: 'v1')
    label.create(resource_guid: li4.guid, key_prefix: 'unique_prefix', key_name: lkey_d, value: 'v1')

    # === Run migration once ===
    expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

    # === Verify annotations behavior ===

    # Verify truncation behavior
    expect(trunc_a1.reload.key_name).to eq(truncated_key_name)
    expect(trunc_a2.reload.key_name).to eq(key_name_short)

    # Verify duplicate removal (keeps smallest id)
    expect(annotation.where(resource_guid: i2.guid, key_name: key_c).count).to eq(2)
    expect(ann_dup_a1.reload).to be_a(annotation)
    expect { ann_dup_a2.reload }.to raise_error(Sequel::NoExistingObject)
    expect { ann_dup_a3.reload }.to raise_error(Sequel::NoExistingObject)
    expect(ann_dup_b1.reload).to be_a(annotation)
    expect { ann_dup_b2.reload }.to raise_error(Sequel::NoExistingObject)
    expect { ann_dup_b3.reload }.to raise_error(Sequel::NoExistingObject)

    # Verify preservation of records with different columns
    expect(ann_pres_a1.reload).to be_a(annotation)
    expect(ann_pres_a2.reload).to be_a(annotation)
    expect(ann_pres_a3.reload).to be_a(annotation)
    expect(ann_pres_b1.reload).to be_a(annotation)
    expect(ann_pres_b2.reload).to be_a(annotation)
    expect(ann_pres_b3.reload).to be_a(annotation)
    expect(ann_pres_b4.reload).to be_a(annotation)

    # Verify uniqueness constraints: does not allow adding a duplicate
    expect { annotation.create(resource_guid: i4.guid, key_name: key_f, value: 'v2') }.to raise_error(Sequel::UniqueConstraintViolation)
    expect { annotation.create(resource_guid: i5.guid, key_prefix: 'unique_prefix', key_name: key_f, value: 'v2') }.to raise_error(Sequel::UniqueConstraintViolation)

    # Verify uniqueness constraints: does allow adding different annotations
    ann_uniq_a1 = annotation.create(resource_guid: i4.guid, key_name: key_g, value: 'v3')
    ann_uniq_a2 = annotation.create(resource_guid: i5.guid, key_name: key_g, value: 'v2')
    ann_uniq_b1 = annotation.create(resource_guid: i4.guid, key_prefix: 'other_prefix', key_name: key_f, value: 'v4')
    ann_uniq_b2 = annotation.create(resource_guid: i5.guid, key_prefix: 'other_prefix', key_name: key_f, value: 'v5')
    expect(annotation.where(key_name: key_g).count).to eq(2)
    expect(ann_uniq_a1.reload).to be_a(annotation)
    expect(ann_uniq_a2.reload).to be_a(annotation)
    expect(ann_uniq_b1.reload).to be_a(annotation)
    expect(ann_uniq_b2.reload).to be_a(annotation)

    # === Verify labels behavior ===

    # Verify duplicate removal (keeps smallest id)
    expect(label.where(resource_guid: li1.guid, key_name: lkey_a).count).to eq(2)
    expect(lbl_dup_a1.reload).to be_a(label)
    expect { lbl_dup_a2.reload }.to raise_error(Sequel::NoExistingObject)
    expect { lbl_dup_a3.reload }.to raise_error(Sequel::NoExistingObject)
    expect(lbl_dup_b1.reload).to be_a(label)
    expect { lbl_dup_b2.reload }.to raise_error(Sequel::NoExistingObject)
    expect { lbl_dup_b3.reload }.to raise_error(Sequel::NoExistingObject)

    # Verify preservation of records with different columns
    expect(lbl_pres_a1.reload).to be_a(label)
    expect(lbl_pres_a2.reload).to be_a(label)
    expect(lbl_pres_a3.reload).to be_a(label)
    expect(lbl_pres_b1.reload).to be_a(label)
    expect(lbl_pres_b2.reload).to be_a(label)
    expect(lbl_pres_b3.reload).to be_a(label)
    expect(lbl_pres_b4.reload).to be_a(label)

    # Verify uniqueness constraints: does not allow adding a duplicate
    expect { label.create(resource_guid: li3.guid, key_name: lkey_d, value: 'v2') }.to raise_error(Sequel::UniqueConstraintViolation)
    expect { label.create(resource_guid: li4.guid, key_prefix: 'unique_prefix', key_name: lkey_d, value: 'v2') }.to raise_error(Sequel::UniqueConstraintViolation)

    # Verify uniqueness constraints: does allow adding different labels
    lbl_uniq_a1 = label.create(resource_guid: li3.guid, key_name: lkey_e, value: 'v3')
    lbl_uniq_a2 = label.create(resource_guid: li4.guid, key_name: lkey_e, value: 'v2')
    lbl_uniq_b1 = label.create(resource_guid: li3.guid, key_prefix: 'other_prefix', key_name: lkey_d, value: 'v4')
    lbl_uniq_b2 = label.create(resource_guid: li4.guid, key_prefix: 'other_prefix', key_name: lkey_d, value: 'v5')
    expect(label.where(key_name: lkey_e).count).to eq(2)
    expect(lbl_uniq_a1.reload).to be_a(label)
    expect(lbl_uniq_a2.reload).to be_a(label)
    expect(lbl_uniq_b1.reload).to be_a(label)
    expect(lbl_uniq_b2.reload).to be_a(label)
  end
end
