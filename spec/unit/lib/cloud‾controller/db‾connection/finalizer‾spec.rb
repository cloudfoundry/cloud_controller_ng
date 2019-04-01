require 'spec_helper'
require 'cloud_controller/db_connection/finalizer'

RSpec.describe VCAP::CloudController::DbConnection::Finalizer do
  class FakeDBPool
    attr_accessor :connection_validation_timeout
  end

  class FakeDBConnection
    attr_accessor :logger, :sql_log_level, :default_collate
    attr_reader :pool, :database_type

    def initialize(type)
      @pool = FakeDBPool.new
      @database_type = type
    end

    def extension(value)
      @extension = value
    end
  end

  subject { VCAP::CloudController::DbConnection::Finalizer }

  let(:database_type) { '' }
  let(:db_connection) { FakeDBConnection.new(database_type) }
  let(:logger) { double(:logger) }

  it 'returns the db connection after finalizing' do
    finalized_connection = subject.finalize(db_connection, {}, logger)

    expect(finalized_connection).to eq(db_connection)
  end

  it 'sets the connection validator extension' do
    allow(db_connection).to receive(:extension)

    subject.finalize(db_connection, {}, logger)

    expect(db_connection).
      to have_received(:extension).with(:connection_validator)
  end

  context 'query logging' do
    context 'when requested' do
      it 'sets the logging levels' do
        subject.finalize(db_connection, { log_db_queries: true, log_level: 'log-level' }, logger)
        expect(db_connection.logger).to eq(logger)
        expect(db_connection.sql_log_level).to eq('log-level')
      end
    end

    context 'when not requested' do
      it 'does not set the logging levels' do
        subject.finalize(db_connection, { log_db_queries: false, log_level: 'log-level' }, logger)
        expect(db_connection.logger).to be_nil
        expect(db_connection.sql_log_level).to be_nil
      end
    end
  end

  context 'connection validation timeout' do
    context 'when requested' do
      it 'sets the timeout' do
        subject.finalize(db_connection, { connection_validation_timeout: 1000 }, logger)
        expect(db_connection.pool.connection_validation_timeout).to eq(1000)
      end
    end

    context 'when not requested' do
      it 'does not set the timeout' do
        subject.finalize(db_connection, {}, logger)
        expect(db_connection.pool.connection_validation_timeout).to be_nil
      end
    end
  end

  context 'default collation' do
    context 'when the db is MySQL' do
      let(:database_type) { :mysql }
      it 'sets the default collation' do
        subject.finalize(db_connection, {}, logger)
        expect(db_connection.default_collate).to eq('utf8_bin')
      end
    end

    context 'when the db is Postgres' do
      let(:database_type) { :postgres }
      it 'does not set the default collation' do
        subject.finalize(db_connection, {}, logger)
        expect(db_connection.default_collate).to be_nil
      end
    end
  end
end
