require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Sequel::Dataset do
    describe '#post_load', type: :model do
      let(:logs) { StringIO.new }
      let(:logger) { Logger.new(logs) }
      let(:db) { Space.db }

      before do
        db.loggers << logger
      end

      describe 'with logging enabled' do
        before do
          db.opts.merge!({ log_db_queries: true, query_size_log_threshold: 5 })
        end

        it 'logs the number of returned rows over threshold' do
          10.times { Space.make }
          Space.all
          expect(logs.string).to match 'Loaded 10 records for query SELECT \* FROM [`"]spaces[`"]'
        end

        it 'does not log the number of returned rows under threshold' do
          2.times { Space.make }
          Space.all
          expect(logs.string).to_not match 'Loaded'
        end
      end

      describe 'with no threshold set' do
        before do
          db.opts.merge!({ log_db_queries: true, query_size_log_threshold: nil })
        end

        it 'does not log' do
          2.times { Space.make }
          Space.all
          expect(logs.string).to_not match 'Loaded'
        end
      end

      describe 'with db query logging not enabled' do
        before do
          db.opts.merge!({ log_db_queries: false, query_size_log_threshold: 1 })
        end

        it 'does not log the number of returned rows under threshold' do
          2.times { Space.make }
          Space.all
          expect(logs.string).to_not match 'Loaded'
        end
      end
    end
  end
end
