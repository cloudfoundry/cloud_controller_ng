require 'spec_helper'
require 'cloud_controller/database_parts_parser'

RSpec.describe VCAP::CloudController::DatabasePartsParser do
  describe '.database_parts_from_connection' do
    context 'converts from a connection string' do
      it 'with a password containing no special characters' do
        parts = VCAP::CloudController::DatabasePartsParser.
                database_parts_from_connection(
                  'mysql://user:p4ssw0rd@example.com:1234/databasename')

        expect(parts).to eq({
                              adapter: 'mysql',
                              host: 'example.com',
                              port: 1234,
                              user: 'user',
                              password: 'p4ssw0rd',
                              database: 'databasename'
                            })
      end

      it 'with an escaped password value' do
        parts = VCAP::CloudController::DatabasePartsParser.
                database_parts_from_connection(
                  'mysql://user:p4s%40sw0rd@example.com:1234/databasename')

        expect(parts).to eq({
                              adapter: 'mysql',
                              host: 'example.com',
                              port: 1234,
                              user: 'user',
                              password: 'p4s@sw0rd',
                              database: 'databasename'
                            })
      end

      it 'throws when parsing an unescaped password value' do
        uri = 'mysql://user:p4s sw0rd@example.com:1234/databasename'
        expect {
          VCAP::CloudController::DatabasePartsParser.database_parts_from_connection(uri)
        }.to raise_error(URI::InvalidURIError, "bad URI(is not URI?): \"#{uri}\"")
      end
    end
  end

  describe '.connection_from_database_parts' do
    context 'converts to a connection string' do
      it 'with a password containing no special characters' do
        connection_string = VCAP::CloudController::DatabasePartsParser.
                            connection_from_database_parts({
                                           adapter: 'mysql',
                                           host: 'example.com',
                                           port: 1234,
                                           user: 'user',
                                           password: 'p4ssw0rd',
                                           database: 'databasename'
                                         })

        expect(connection_string).to eq('mysql://user:p4ssw0rd@example.com:1234/databasename')
      end

      it 'with an escaped password value' do
        connection_string = VCAP::CloudController::DatabasePartsParser.
                            connection_from_database_parts({
                                           adapter: 'mysql',
                                           host: 'example.com',
                                           port: 1234,
                                           user: 'user',
                                           password: 'p4s@sw0rd',
                                           database: 'databasename'
                                         })

        expect(connection_string).to eq('mysql://user:p4s%40sw0rd@example.com:1234/databasename')
      end
    end
  end
end
