require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to streamline changes to annotation_key_prefix', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20230822153000_streamline_annotation_key_prefix.rb' }
  end

  describe 'annotation tables' do
    it 'converts legacy key_prefixes to prefixes in key_prefix column and leaves non-legacy values unchanged' do
      db[:isolation_segments].insert(name: 'bommel', guid: '123')
      db[:isolation_segment_annotations].insert(
        guid: 'bommel',
        created_at: Time.now - 60,
        updated_at: Time.now - 60,
        resource_guid: '123',
        key: 'mylegacyprefix/mykey',
        value: 'some_value'
      )
      db[:isolation_segment_annotations].insert(guid: 'bommel2', resource_guid: '123', key_prefix: 'myprefix', key: 'mykey', value: 'some_value')
      db[:isolation_segment_annotations].insert(guid: 'bommel3', resource_guid: '123', key: 'mykey2', value: 'some_value2')

      a1 = db[:isolation_segment_annotations].first(key: 'mylegacyprefix/mykey')
      b1 = db[:isolation_segment_annotations].first(key: 'mykey')
      b2 = db[:isolation_segment_annotations].first(key: 'mykey2')

      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

      # Check legacy prefix was converted
      a1_after = db[:isolation_segment_annotations].first(guid: 'bommel')
      expect(a1_after[:guid]).to eq a1[:guid]
      expect(a1_after[:created_at]).to eq a1[:created_at]
      expect(a1_after[:updated_at]).not_to eq a1[:updated_at]
      expect(a1_after[:resource_guid]).to eq a1[:resource_guid]
      expect(a1_after[:key_prefix]).not_to eq a1[:key_prefix]
      expect(a1_after[:key]).not_to eq a1[:key]
      expect(a1_after[:key_prefix]).to eq 'mylegacyprefix'
      expect(a1_after[:key]).to eq 'mykey'

      # Check non-legacy values unchanged
      c1 = db[:isolation_segment_annotations].first(guid: 'bommel2')
      c2 = db[:isolation_segment_annotations].first(guid: 'bommel3')
      expect(b1.values).to eq(c1.values)
      expect(b2.values).to eq(c2.values)
    end
  end
end
