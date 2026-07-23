require 'lightweight_spec_helper'
require 'cloud_controller/db_connection/postgres_options_factory'

RSpec.describe VCAP::CloudController::DbConnection::PostgresOptionsFactory do
  let(:required_options) { { database: { adapter: 'postgres' } } }

  describe 'when the Cloud Controller Config specifies Postgres' do
    let(:ssl_verify_hostname) { true }
    let(:ca_cert_path) { nil }
    let(:postgres_options) do
      VCAP::CloudController::DbConnection::PostgresOptionsFactory.build(
        database: {
          adapter: 'postgres'
        },
        ca_cert_path: ca_cert_path,
        ssl_verify_hostname: ssl_verify_hostname
      )
    end

    it 'sets the timezone via connect_sqls' do
      expect(postgres_options[:connect_sqls]).to include("SET time zone 'UTC'")
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

    describe 'connection parameters' do
      context 'when no connection parameters are set' do
        let(:postgres_options) do
          VCAP::CloudController::DbConnection::PostgresOptionsFactory.build(
            database: { adapter: 'postgres' }
          )
        end

        it 'only sets the timezone in connect_sqls' do
          expect(postgres_options[:connect_sqls]).to eq(["SET time zone 'UTC'"])
        end

        it 'does not include any keepalive options in the returned hash' do
          expect(postgres_options[:keepalives]).to be_nil
          expect(postgres_options[:keepalives_idle]).to be_nil
          expect(postgres_options[:keepalives_interval]).to be_nil
          expect(postgres_options[:keepalives_count]).to be_nil
        end
      end

      context 'when SQL params are set' do
        let(:postgres_options) do
          VCAP::CloudController::DbConnection::PostgresOptionsFactory.build(
            database: { adapter: 'postgres' },
            psql: {
              statement_timeout: 3_600_000,
              idle_in_transaction_session_timeout: 600_000
            }
          )
        end

        it 'sets the SQL params via connect_sqls' do
          expect(postgres_options[:connect_sqls]).to include("SET time zone 'UTC'")
          expect(postgres_options[:connect_sqls]).to include("SET statement_timeout TO '3600000'")
          expect(postgres_options[:connect_sqls]).to include("SET idle_in_transaction_session_timeout TO '600000'")
        end

        it 'does not put SQL params into the returned options hash' do
          expect(postgres_options[:statement_timeout]).to be_nil
          expect(postgres_options[:idle_in_transaction_session_timeout]).to be_nil
        end
      end

      context 'when libpq keepalive params are set' do
        let(:postgres_options) do
          VCAP::CloudController::DbConnection::PostgresOptionsFactory.build(
            database: { adapter: 'postgres' },
            psql: {
              keepalives: 1,
              keepalives_idle: 30,
              keepalives_interval: 10,
              keepalives_count: 3
            }
          )
        end

        it 'merges keepalive params into the returned options hash' do
          expect(postgres_options[:keepalives]).to eq(1)
          expect(postgres_options[:keepalives_idle]).to eq(30)
          expect(postgres_options[:keepalives_interval]).to eq(10)
          expect(postgres_options[:keepalives_count]).to eq(3)
        end

        it 'does not SET keepalive params via connect_sqls' do
          expect(postgres_options[:connect_sqls]).not_to include(match(/SET keepalives/))
        end
      end

      context 'when both SQL and libpq params are set' do
        let(:postgres_options) do
          VCAP::CloudController::DbConnection::PostgresOptionsFactory.build(
            database: { adapter: 'postgres' },
            psql: {
              statement_timeout: 3_600_000,
              keepalives: 1,
              keepalives_idle: 30,
              keepalives_interval: 10,
              keepalives_count: 3
            }
          )
        end

        it 'sets SQL params via connect_sqls and merges libpq params into options hash' do
          expect(postgres_options[:connect_sqls]).to include("SET statement_timeout TO '3600000'")
          expect(postgres_options[:keepalives]).to eq(1)
          expect(postgres_options[:keepalives_idle]).to eq(30)
          expect(postgres_options[:keepalives_interval]).to eq(10)
          expect(postgres_options[:keepalives_count]).to eq(3)
        end

        it 'does not mix up the two kinds: SQL params not in options hash, libpq params not SET via SQL' do
          expect(postgres_options[:statement_timeout]).to be_nil
          expect(postgres_options[:connect_sqls]).not_to include(match(/SET keepalives/))
        end
      end
    end
  end
end
