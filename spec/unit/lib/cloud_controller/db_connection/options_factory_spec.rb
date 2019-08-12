require 'spec_helper'
require 'cloud_controller/db_connection/options_factory'
require 'cloud_controller/db_connection/mysql_options_factory'

RSpec.describe VCAP::CloudController::DbConnection::OptionsFactory do
  let(:adapter) { '' }
  let(:required_options) { { database: { adapter: adapter } } }

  describe '.build' do
    describe 'database schemes' do
      it 'raises if the database_scheme is unsupported' do
        expect {
          VCAP::CloudController::DbConnection::OptionsFactory.build(database: { adapter: 'foo' })
        }.to raise_error(VCAP::CloudController::DbConnection::UnknownSchemeError, /Unknown .* 'foo'/)
      end

      it 'raises if the database_scheme is missing' do
        expect {
          VCAP::CloudController::DbConnection::OptionsFactory.build(database: {})
        }.to raise_error(VCAP::CloudController::DbConnection::UnknownSchemeError, /Unknown .* ''/)
      end

      context 'for `mysql`' do
        let(:adapter) { 'mysql' }

        it 'returns mysql-specific options' do
          connection = double('connection', query: '')
          mysql_options = VCAP::CloudController::DbConnection::OptionsFactory.build(required_options)
          mysql_options[:after_connect].call(connection)
          expect(connection).to have_received(:query).with("SET time_zone = '+0:00'")
        end
      end

      context 'for `mysql2`' do
        let(:adapter) { 'mysql2' }

        it 'returns mysql-specific options' do
          connection = double('connection', query: '')
          mysql_options = VCAP::CloudController::DbConnection::OptionsFactory.build(required_options)
          mysql_options[:after_connect].call(connection)
          expect(connection).to have_received(:query).with("SET time_zone = '+0:00'")
        end
      end

      context 'for `postgres`' do
        let(:adapter) { 'postgres' }

        it 'returns postgres-specific options' do
          connection = double('connection', exec: '')
          postgres_options = VCAP::CloudController::DbConnection::OptionsFactory.build(required_options)
          postgres_options[:after_connect].call(connection)
          expect(connection).to have_received(:exec).with("SET time zone 'UTC'")
        end
      end
    end

    describe 'default options' do
      let(:adapter) { ['mysql', 'postgres'].sample }

      it 'sets the sql_mode' do
        db_connection_options = VCAP::CloudController::DbConnection::OptionsFactory.build(required_options)

        expect(db_connection_options[:sql_mode]).to eq([:strict_trans_tables, :strict_all_tables, :no_zero_in_date])
      end

      it 'sets the max connections' do
        db_connection_options = VCAP::CloudController::DbConnection::OptionsFactory.
                                build(required_options.merge(max_connections: 3000))

        expect(db_connection_options[:max_connections]).to eq(3000)
      end

      it 'sets the pool timeout' do
        db_connection_options = VCAP::CloudController::DbConnection::OptionsFactory.
                                build(required_options.merge(pool_timeout: 2000))

        expect(db_connection_options[:pool_timeout]).to eq(2000)
      end

      it 'sets the read timeout' do
        db_connection_options = VCAP::CloudController::DbConnection::OptionsFactory.
                                build(required_options.merge(read_timeout: 1000))
        expect(db_connection_options[:read_timeout]).to eq(1000)
      end

      it 'sets the db log level' do
        db_connection_options = VCAP::CloudController::DbConnection::OptionsFactory.
                                build(required_options.merge(log_level: 'super-high'))

        expect(db_connection_options[:log_level]).to eq('super-high')
      end

      it 'sets the option for logging db queries' do
        db_connection_options = VCAP::CloudController::DbConnection::OptionsFactory.
                                build(required_options.merge(log_db_queries: true))

        expect(db_connection_options[:log_db_queries]).to eq(true)
      end

      it 'sets the connection_validation_timeout' do
        db_connection_options = VCAP::CloudController::DbConnection::OptionsFactory.
                                build(required_options.merge(connection_validation_timeout: 42))

        expect(db_connection_options[:connection_validation_timeout]).to eq(42)
      end

      it 'up-levels the database parts' do
        db_connection_options = VCAP::CloudController::DbConnection::OptionsFactory.
                                build(required_options.merge(
                                        database: {
                                          adapter: 'mysql',
                                          host: 'example.com',
                                          port: 1234,
                                          user: 'user',
                                          password: 'p4ssw0rd',
                                          database: 'databasename'
                                        }
          ))

        expect(db_connection_options).to include(
          adapter: 'mysql',
          host: 'example.com',
          port: 1234,
          user: 'user',
          password: 'p4ssw0rd',
          database: 'databasename'
        )
      end
    end
  end
end
