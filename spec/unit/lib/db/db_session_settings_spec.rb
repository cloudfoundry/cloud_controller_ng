require 'spec_helper'

describe 'Db connection sessions' do
  it 'sets the timezone to UTC' do
    conn = DbConfig.new.connection
    type = conn.database_type

    if type == :postgres
      timestamp = conn['select current_timestamp'].first.values.first.to_s
      expect(timestamp).to include('UTC')
    elsif type == :mysql
      timestamp = conn['select curtime()'].first.values.first.to_s
      expect(timestamp).to include('UTC')
    end
  end
end
