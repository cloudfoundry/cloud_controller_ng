require 'spec_helper'

RSpec.describe 'create singleton timestamp of last update to asgs', isolation: :truncation do
  let(:db) { Sequel::Model.db }
  let(:user) { VCAP::CloudController::User.make }
  let(:tmp_migrations_dir) { Dir.mktmpdir }

  it 'creates the asg update table' do
    expect(db.table_exists?(:asg_latest_updates)).to be_truthy
  end

  it 'only allows one updated timestamp row' do
    db[:asg_latest_updates].insert({ last_update: DateTime.now })
    expect {
      db[:asg_latest_updates].insert({ last_update: DateTime.now })
    }.to raise_error(Exception)
  end
end
