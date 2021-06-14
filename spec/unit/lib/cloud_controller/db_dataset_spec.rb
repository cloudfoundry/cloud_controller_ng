require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Sequel::Dataset do
    describe '#post_load', type: :model do
      let(:logs) { StringIO.new }
      let(:logger) { Logger.new(logs) }
      let(:db) { Route.db }

      before do
        db.opts.merge!({ log_db_queries: true, query_size_log_threshold: 1 })
        db.loggers << logger
      end

      it 'log the number of returned rows' do
        space = Space.make
        Route.make(space: space)
        Route.dataset.eager(:space).all
        expect(logs.string).to match 'Loaded 1 records for query SELECT \* FROM "routes"'
      end
    end
  end
end
