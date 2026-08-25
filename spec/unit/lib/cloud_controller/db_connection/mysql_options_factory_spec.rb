require 'spec_helper'
require 'cloud_controller/db_connection/mysql_options_factory'

RSpec.describe VCAP::CloudController::DbConnection::MysqlOptionsFactory do
  let(:required_options) { { database: { adapter: 'mysql' } } }

  describe 'when the Cloud Controller Config specifies MySQL' do
    let(:ssl_verify_hostname) { true }
    let(:ca_cert_path) { nil }
    let(:ssl_mode) { nil }
    let(:mysql_options) do
      VCAP::CloudController::DbConnection::MysqlOptionsFactory.build(
        database: {
          adapter: 'mysql2'
        },
        ca_cert_path: ca_cert_path,
        ssl_verify_hostname: ssl_verify_hostname,
        ssl_mode: ssl_mode
      )
    end

    it 'the charset should be set' do
      expect(mysql_options[:charset]).to eq('utf8')
    end

    it 'sets the timezone via a Proc' do
      connection = double('connection', query: '')
      mysql_options[:after_connect].call(connection)
      expect(connection).to have_received(:query).with("SET time_zone = '+0:00'")
    end

    describe 'when the CA cert path is not set' do
      it 'the options do not specify SSL' do
        expect(mysql_options[:ca_cert_path]).to be_nil
        expect(mysql_options[:sslca]).to be_nil
        expect(mysql_options[:ssl_mode]).to be_nil
        expect(mysql_options[:sslverify]).to be_nil
      end

      describe 'when ssl_mode is set' do
        context 'when ssl_mode is required' do
          let(:ssl_mode) { 'required' }

          it 'sets ssl_mode to :required without a CA' do
            expect(mysql_options[:ssl_mode]).to eq(:required)
            expect(mysql_options[:sslca]).to be_nil
          end
        end

        context 'when ssl_mode is disabled' do
          let(:ssl_mode) { 'disabled' }

          it 'sets ssl_mode to :disabled' do
            expect(mysql_options[:ssl_mode]).to eq(:disabled)
          end
        end

        context 'when ssl_mode is an unsupported value' do
          let(:ssl_mode) { 'prefer' }

          it 'raises an ArgumentError' do
            expect { mysql_options }.to raise_error(ArgumentError, /Unsupported ccdb.ssl_mode 'prefer' for mysql/)
          end
        end
      end
    end

    describe 'when the CA cert path is set' do
      let(:ca_cert_path) { '/path/to/db_ca.crt' }

      it 'sets the ssl root cert' do
        expect(mysql_options[:sslca]).to eq('/path/to/db_ca.crt')
      end

      describe 'ssl verification' do
        context 'when ssl_verify_hostname is truthy' do
          let(:ssl_verify_hostname) { true }

          it 'enables full server certificate verification' do
            expect(mysql_options[:sslverify]).to be(true)
          end
        end

        context 'when ssl_verify_hostname is falsey' do
          let(:ssl_verify_hostname) { false }

          it 'sets the CA without enabling sslverify' do
            expect(mysql_options[:sslca]).to eq('/path/to/db_ca.crt')
            expect(mysql_options[:sslverify]).to be_nil
          end
        end
      end

      context 'when ssl_mode is also set' do
        let(:ssl_mode) { 'required' }

        it 'ignores ssl_mode and uses the CA verification path' do
          expect(mysql_options[:sslca]).to eq('/path/to/db_ca.crt')
          expect(mysql_options[:sslverify]).to be(true)
          expect(mysql_options[:ssl_mode]).to be_nil
        end
      end
    end
  end
end
