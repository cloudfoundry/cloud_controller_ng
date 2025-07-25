require 'spec_helper'

RSpec.describe Sequel::RequestQueryCounter do
  let(:db) { DbConfig.new.connection }

  before do
    db.extension(:request_query_counter)
  end

  it 'increments the thread local query count on each query' do
    expect do
      db.fetch('SELECT 1').all
    end.to change(VCAP::Request, :db_query_count).by(1)
  end
end
