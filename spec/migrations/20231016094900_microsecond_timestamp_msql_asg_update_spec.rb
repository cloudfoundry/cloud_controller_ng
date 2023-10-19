require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to enable microsecond precision on asg last updated table', isolation: :truncation do
  include_context 'migration' do
    let(:migration_filename) { '20231016094900_microsecond_timestamp_msql_asg_update.rb' }
    let(:ds) { db[:asg_timestamps].with_extend do
        def supports_timestamp_usecs?
          true
        end
        def timestamp_precision
          6
        end
    end

    }
  end

  describe 'asg_timestamps table' do
    it 'the last_update column handles sub-second time' do
      initial_time = DateTime.new(2010)

      ds.insert(id: 1, last_update: initial_time)
      t1 = ds.first(id: 1)
      expect(t1[:last_update].to_datetime.rfc3339(6)).to eq(initial_time.rfc3339(6))

      # Change TIMESTAMP to TIMESTAMP(6)
      expect { Sequel::Migrator.run(db, migration_to_test, allow_missing_migration_files: true) }.not_to raise_error

      # the migration shouldn't add accuracy to previously inserted values
      t1_post_migration = ds.first(id: 1)
      expect(t1_post_migration[:last_update].to_datetime.rfc3339(6)).to eq(initial_time.rfc3339(6))

      # but new data should retain microsecond accuracy
      post_migration_time = DateTime.now
      ds.insert(id: 2, last_update: post_migration_time)
      t2 = ds.first(id: 2)
      expect(t2[:last_update].to_datetime.rfc3339(6)).to eq(post_migration_time.rfc3339(6))
    end
  end
end
