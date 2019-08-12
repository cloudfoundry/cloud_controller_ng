require 'spec_helper'
require 'cloud_controller/db_connection/mysql_options_factory'

RSpec.describe VCAP::CloudController::DbConnection::MysqlOptionsFactory do
  let(:required_options) { { database: { adapter: 'mysql' } } }

  describe 'when the Cloud Controller Config specifies MySQL' do
    let(:ssl_verify_hostname) { true }
    let(:ca_cert_path) { nil }
    let(:mysql_options) do
      VCAP::CloudController::DbConnection::MysqlOptionsFactory.build(
        database: {
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
end
