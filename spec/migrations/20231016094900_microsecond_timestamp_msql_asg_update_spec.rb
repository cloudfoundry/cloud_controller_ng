require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to enable microsecond precision on asg last updated table', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20231016094900_microsecond_timestamp_msql_asg_update.rb' }
    let(:ds) do
      db[:asg_timestamps].with_extend do
        def supports_timestamp_usecs?
          true
        end
      end
    end
  end

  describe 'asg_timestamps table' do
    it 'the last_update column handles sub-second time' do
      dt_without_fractional_seconds = DateTime.new(2001, 2, 3, 4, 5, 6)
      dt_with_fractional_seconds = dt_without_fractional_seconds.advance(seconds: 0.123456)

      ds.insert(id: 1, last_update: dt_with_fractional_seconds)
      t1 = ds.first(id: 1)

      if db.database_type == :mysql
        expect(t1[:last_update].to_datetime.subsec).to eq(0)
        expect(t1[:last_update].to_datetime.rfc3339(6)).to eq(dt_without_fractional_seconds.rfc3339(6))
      else
        expect(t1[:last_update].to_datetime.subsec).not_to eq(0)
        expect(t1[:last_update].to_datetime.rfc3339(6)).to eq(dt_with_fractional_seconds.rfc3339(6))
      end

      # Change TIMESTAMP to TIMESTAMP(6)
      expect { Sequel::Migrator.run(db, migration_to_test, allow_missing_migration_files: true) }.not_to raise_error

      # the migration shouldn't add accuracy to previously inserted values
      t1_post_migration = ds.first(id: 1)
      expect(t1_post_migration[:last_update].to_datetime.rfc3339(6)).to eq(t1[:last_update].to_datetime.rfc3339(6))

      # but new data should retain microsecond accuracy
      ds.insert(id: 2, last_update: dt_with_fractional_seconds)
      t2 = ds.first(id: 2)

      expect(t2[:last_update].to_datetime.subsec).not_to eq(0)
      expect(t2[:last_update].to_datetime.rfc3339(6)).to eq(dt_with_fractional_seconds.rfc3339(6))
    end
  end
end
