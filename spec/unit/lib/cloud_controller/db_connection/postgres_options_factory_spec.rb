require 'spec_helper'
require 'cloud_controller/db_connection/postgres_options_factory'

RSpec.describe VCAP::CloudController::DbConnection::PostgresOptionsFactory do
  let(:required_options) { { database: { adapter: 'postgres' } } }

  describe 'when the Cloud Controller Config specifies Postgres' do
    let(:ssl_verify_hostname) { true }
    let(:ca_cert_path) { nil }
    let(:postgres_options) do
      VCAP::CloudController::DbConnection::PostgresOptionsFactory.build(
        database: {
          adapter: 'postgres' },
        ca_cert_path: ca_cert_path,
        ssl_verify_hostname: ssl_verify_hostname
      )
    end

    it 'should set the timezone via a Proc' do
      connection = double('connection', exec: '')
      postgres_options[:after_connect].call(connection)
      expect(connection).to have_received(:exec).with("SET time zone 'UTC'")
    end

    describe 'when the CA cert path is not set' do
      it 'the options do not specify SSL' do
        expect(postgres_options[:ca_cert_path]).to be_nil
        expect(postgres_options[:sslrootcert]).to be_nil
        expect(postgres_options[:sslmode]).to be_nil
        expect(postgres_options[:ssl_verify_hostname]).to be_nil
      end
    end

    describe 'when the CA cert path is set' do
      let(:ca_cert_path) { '/path/to/db_ca.crt' }
      it 'sets the ssl root cert' do
        expect(postgres_options[:sslrootcert]).to eq('/path/to/db_ca.crt')
      end

      describe 'sslmode' do
        context 'when ssl_verify_hostname is truthy' do
          let(:ssl_verify_hostname) { true }

          it 'sets the sslmode to "verify-full"' do
            expect(postgres_options[:sslmode]).to eq('verify-full')
          end
        end
        context 'when ssl_verify_hostname is falsey' do
          let(:ssl_verify_hostname) { false }

          it 'sets the sslmode to "verify-ca"' do
            expect(postgres_options[:sslmode]).to eq('verify-ca')
          end
        end
      end
    end
  end
end
