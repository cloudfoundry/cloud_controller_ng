require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to streamline changes to annotation_key_prefix', isolation: :truncation do
  include_context 'migration' do
    let(:migration_filename) { '20230822153000_streamline_annotation_key_prefix.rb' }
  end

  describe 'annotation tables' do
    it 'converts all legacy key_prefixes to annotations with prefixes in the key_prefix column' do
      db[:isolation_segments].insert(name: 'bommel', guid: '123')
      db[:isolation_segment_annotations].insert(
        guid: 'bommel',
        created_at: Time.now - 60,
        updated_at: Time.now - 60,
        resource_guid: '123',
        key: 'mylegacyprefix/mykey',
        value: 'some_value')
      a1 = db[:isolation_segment_annotations].first(resource_guid: '123')
      expect { Sequel::Migrator.run(db, migration_to_test, allow_missing_migration_files: true) }.not_to raise_error
      b1 = db[:isolation_segment_annotations].first(resource_guid: '123')
      expect(b1[:guid]).to eq a1[:guid]
      expect(b1[:created_at]).to eq a1[:created_at]
      expect(b1[:updated_at]).to_not eq a1[:updated_at]
      expect(b1[:resource_guid]).to eq a1[:resource_guid]
      expect(b1[:key_prefix]).to_not eq a1[:key_prefix]
      expect(b1[:key]).to_not eq a1[:key]
      expect(b1[:key_prefix]).to eq 'mylegacyprefix'
      expect(b1[:key]).to eq 'mykey'
    end

    it 'doesnt touch any values that have no legacy key_prefix in its key field' do
      db[:isolation_segments].insert(name: 'bommel', guid: '123')
      db[:isolation_segment_annotations].insert(guid: 'bommel', resource_guid: '123', key_prefix: 'myprefix', key: 'mykey', value: 'some_value')
      db[:isolation_segment_annotations].insert(guid: 'bommel2', resource_guid: '123', key: 'mykey2', value: 'some_value2')
      b1 = db[:isolation_segment_annotations].first(key: 'mykey')
      b2 = db[:isolation_segment_annotations].first(key: 'mykey2')
      expect { Sequel::Migrator.run(db, migration_to_test, allow_missing_migration_files: true) }.not_to raise_error
      c1 = db[:isolation_segment_annotations].first(key: 'mykey')
      c2 = db[:isolation_segment_annotations].first(key: 'mykey2')
      expect(b1.values).to eq(c1.values)
      expect(b2.values).to eq(c2.values)
    end
  end
end
