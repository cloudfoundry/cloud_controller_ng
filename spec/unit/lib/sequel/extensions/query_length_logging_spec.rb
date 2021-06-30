require 'spec_helper'

RSpec.describe Sequel::QueryLengthLogging do
  describe 'log_connection_yield' do
    let(:db) { DbConfig.new.connection }
    let(:logs) { StringIO.new }
    let(:logger) { Logger.new(logs) }

    before do
      db.loggers << logger
      db.sql_log_level = :info
      db.extension(:query_length_logging)
    end

    it 'add the query length parameter' do
      query = 'SELECT * FROM some_table WHERE condition > 1'
      db.log_connection_yield(query, nil) {}
      expect(logs.string).to match /.*\(query_length=44\) SELECT \* FROM some_table WHERE condition > 1/
    end
  end
end
