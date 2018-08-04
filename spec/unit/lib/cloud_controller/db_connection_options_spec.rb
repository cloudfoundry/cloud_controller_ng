require 'spec_helper'
require 'cloud_controller/db_connection_options'

RSpec.describe VCAP::CloudController::DBConnectionOptionsFactory do
  let(:required_options) { { database_parts: { adapter: 'mysql' } } }

  describe '.build' do
    it 'raises if the database_scheme is unsupported' do
      expect {
        VCAP::CloudController::DBConnectionOptionsFactory.build(database_parts: { adapter: 'foo' })
      }.to raise_error(VCAP::CloudController::DBConnectionOptionsFactory::UnknownSchemeError)
    end

    describe 'default options' do
      it 'sets the sql_mode as expected' do
        db_connection_options = VCAP::CloudController::DBConnectionOptionsFactory.build(required_options)

        expect(db_connection_options[:sql_mode]).to eq([:strict_trans_tables, :strict_all_tables, :no_zero_in_date])
      end
    end

    describe 'when the Cloud Controller config specifies generic options' do
      it 'sets the max connections' do
        db_connection_options = VCAP::CloudController::DBConnectionOptionsFactory.
                                build(required_options.merge(max_connections: 3000))

        expect(db_connection_options[:max_connections]).to eq(3000)
      end

      it 'sets the pool timeout' do
        db_connection_options = VCAP::CloudController::DBConnectionOptionsFactory.
                                build(required_options.merge(pool_timeout: 2000))

        expect(db_connection_options[:pool_timeout]).to eq(2000)
      end

      it 'sets the read timeout' do
        db_connection_options = VCAP::CloudController::DBConnectionOptionsFactory.
                                build(required_options.merge(read_timeout: 1000))
        expect(db_connection_options[:read_timeout]).to eq(1000)
      end

      it 'sets the db log level' do
        db_connection_options = VCAP::CloudController::DBConnectionOptionsFactory.
                                build(required_options.merge(log_level: 'super-high'))

        expect(db_connection_options[:log_level]).to eq('super-high')
      end

      it 'sets the option for logging db queries' do
        db_connection_options = VCAP::CloudController::DBConnectionOptionsFactory.
                                build(required_options.merge(log_db_queries: true))

        expect(db_connection_options[:log_db_queries]).to eq(true)
      end

      it 'sets the connection_validation_timeout' do
        db_connection_options = VCAP::CloudController::DBConnectionOptionsFactory.
                                build(required_options.merge(connection_validation_timeout: 42))

        expect(db_connection_options[:connection_validation_timeout]).to eq(42)
      end

      it 'up-levels the database parts' do
        db_connection_options = VCAP::CloudController::DBConnectionOptionsFactory.
                                build(required_options.merge(
                                        database_parts: {
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

    describe 'when the Cloud Controller Config specifies MySQL' do
      let(:ssl_verify_hostname) { true }
      let(:ca_cert_path) { nil }
      let(:mysql_options) do
        VCAP::CloudController::DBConnectionOptionsFactory.build(
          database_parts: {
            adapter: 'mysql2' },
          ca_cert_path: ca_cert_path,
          ssl_verify_hostname: ssl_verify_hostname
        )
      end

      it 'the charset should be set' do
        expect(mysql_options[:charset]).to eq('utf8')
      end

      it 'should set the timezone via a Proc' do
        connection = double('connection', query: '')
        mysql_options[:after_connect].call(connection)
        expect(connection).to have_received(:query).with("SET time_zone = '+0:00'")
      end

      describe 'when the CA cert path is not set' do
        it 'the options do not specify SSL' do
          expect(mysql_options[:ca_cert_path]).to be_nil
          expect(mysql_options[:sslca]).to be_nil
          expect(mysql_options[:sslmode]).to be_nil
          expect(mysql_options[:sslverify]).to be_nil
        end
      end

      describe 'when the CA cert path is set' do
        let(:ca_cert_path) { '/path/to/db_ca.crt' }
        it 'sets the ssl root cert' do
          expect(mysql_options[:sslca]).to eq('/path/to/db_ca.crt')
        end

        describe 'sslmode' do
          context 'when ssl_verify_hostname is truthy' do
            let(:ssl_verify_hostname) { true }

            it 'sets the ssl verify options' do
              expect(mysql_options[:sslmode]).to eq(:verify_identity)
              expect(mysql_options[:sslverify]).to eq(true)
            end
          end
          context 'when ssl_verify_hostname is falsey' do
            let(:ssl_verify_hostname) { false }

            it 'sets the sslmode to :verify-ca' do
              expect(mysql_options[:sslmode]).to eq(:verify_ca)
            end
          end
        end
      end
    end

    describe 'when the Cloud Controller Config specifies Postgres' do
      let(:ssl_verify_hostname) { true }
      let(:ca_cert_path) { nil }
      let(:postgres_options) do
        VCAP::CloudController::DBConnectionOptionsFactory.build(
          database_parts: {
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
end
