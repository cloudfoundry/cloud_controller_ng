require 'spec_helper'

RSpec.describe Sequel::RequestQueryCounter do
  let(:db) { DbConfig.new.connection }

  before do
    db.extension(:request_query_counter)
  end

  it 'increments the thread local query count on each query' do
    VCAP::Request.reset_db_query_count
    db.fetch('SELECT 1').all
    expect(VCAP::Request.db_query_count).to eq(1)
  end
end
