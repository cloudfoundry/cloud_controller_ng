require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to streamline changes to annotation_key_prefix', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20230822153000_streamline_annotation_key_prefix.rb' }
  end

  describe 'annotation tables' do
    it 'converts legacy key_prefixes to prefixes in key_prefix column and leaves non-legacy values unchanged' do
      resource_guid = 'iso-seg-guid'
      db[:isolation_segments].insert(name: 'iso_seg', guid: resource_guid)
      db[:isolation_segment_annotations].insert(guid: 'anno-1-guid', resource_guid: resource_guid, key: 'mylegacyprefix/mykey', value: 'some_value')
      db[:isolation_segment_annotations].insert(guid: 'anno-2-guid', resource_guid: resource_guid, key_prefix: 'myprefix', key: 'mykey', value: 'some_value')
      db[:isolation_segment_annotations].insert(guid: 'anno-3-guid', resource_guid: resource_guid, key: 'yourkey', value: 'some_other_value')

      anno1 = db[:isolation_segment_annotations].first(guid: 'anno-1-guid')
      anno2 = db[:isolation_segment_annotations].first(key: 'mykey')
      anno3 = db[:isolation_segment_annotations].first(key: 'yourkey')

      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

      # Check legacy prefix was converted
      anno1_after_mig = db[:isolation_segment_annotations].first(guid: 'anno-1-guid')
      expect(anno1_after_mig[:guid]).to eq anno1[:guid]
      expect(anno1_after_mig[:created_at]).to eq anno1[:created_at]
      expect(anno1_after_mig[:updated_at]).not_to eq anno1[:updated_at]
      expect(anno1_after_mig[:resource_guid]).to eq anno1[:resource_guid]
      expect(anno1_after_mig[:key_prefix]).not_to eq anno1[:key_prefix]
      expect(anno1_after_mig[:key]).not_to eq anno1[:key]
      expect(anno1_after_mig[:key_prefix]).to eq 'mylegacyprefix'
      expect(anno1_after_mig[:key]).to eq 'mykey'

      # Check non-legacy values unchanged
      anno2_after_mig = db[:isolation_segment_annotations].first(guid: 'anno-2-guid')
      anno3_after_mig = db[:isolation_segment_annotations].first(guid: 'anno-3-guid')
      expect(anno2.values).to eq(anno2_after_mig.values)
      expect(anno3.values).to eq(anno3_after_mig.values)
    end
  end
end
