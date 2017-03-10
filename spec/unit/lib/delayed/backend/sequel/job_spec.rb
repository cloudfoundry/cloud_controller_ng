require 'spec_helper'

RSpec.describe Delayed::Backend::Sequel::Job do
  it 'has a cf_api_error column that can store large blobs of json' do
    expect(Delayed::Backend::Sequel::Job.columns).to include(:cf_api_error)

    columns = Sequel::Model.db.schema(:delayed_jobs)
    cf_api_error_properties = columns.detect do |name, _|
      name == :cf_api_error
    end.last

    data_type = Sequel::Model.db.database_type == :mssql ? 'varchar' : 'text'
    expect(cf_api_error_properties[:db_type]).to eq(data_type)
  end
end
