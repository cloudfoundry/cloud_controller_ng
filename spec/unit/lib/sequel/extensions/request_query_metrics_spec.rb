require 'spec_helper'

RSpec.describe 'request_query_metrics' do
  let(:db) { DbConfig.new.connection }

  before do
    # Add a logger to the database connection to ensure that the duration is captured
    db.loggers << Logger.new(StringIO.new)
    db.extension(:request_query_metrics)
    allow(VCAP::Request).to receive(:record_db_query).and_wrap_original do |original_method|
      original_method.call(1_234)
    end
  end

  it 'increments the thread local total query time on each query' do
    expect do
      2.times { db.fetch('SELECT 1').all }
    end.to change(VCAP::Request.db_query_metrics, :total_query_time_us).by(2_468)
  end

  it 'increments the thread local query count on each query' do
    expect do
      db.fetch('SELECT 1').all
    end.to change(VCAP::Request.db_query_metrics, :query_count).by(1)
  end
end
