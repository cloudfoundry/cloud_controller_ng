require 'spec_helper'
require 'socket'

$LOAD_PATH.unshift('app')

require 'cloud_controller/opi/base_client'

# This spec requires the OPI binary and `nats-server` to be in $PATH
skip_opi_tests = ENV['CF_RUN_OPI_SPECS'] != 'true'

RSpec.describe(OPI::BaseClient, opi: skip_opi_tests) do
  let(:tls_port) { 8484 }
  let(:opi_url) { "https://localhost:#{tls_port}" }
  let(:ca_cert_file) { File.join(Paths::FIXTURES, 'certs/opi_client.crt') }
  let(:client_cert_file) { File.join(Paths::FIXTURES, 'certs/opi_client.crt') }
  let(:client_key_file) { File.join(Paths::FIXTURES, 'certs/opi_client.key') }
  let(:config) do
    VCAP::CloudController::Config.new(
      opi: {
        url: opi_url,
        client_cert_file: client_cert_file,
        client_key_file: client_key_file,
        ca_file: ca_cert_file
      },
    )
  end
  subject(:client) { described_class.new(config) }
  let(:process) { double(guid: 'jeff', version: '0.1.0') }

  before :all do
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  def client
    client = HTTPClient.new
    client.ssl_config.set_trust_ca(ca_cert_file)
    client.ssl_config.set_client_cert_file(client_cert_file, client_key_file)
    client
  end

  def up?(url)
    client.get(url)
  rescue OpenSSL::SSL::SSLError
    true
  rescue Errno::ECONNREFUSED
    false
  end

  def nats_up?
    TCPSocket.new 'localhost', 4222
  rescue Errno::ECONNREFUSED
    false
  end

  before do
    @nats_pid = Process.spawn('nats-server --user nats --pass nats')
    wait_for { nats_up? }.to be_truthy

    @file = Tempfile.new('opi_config.yml')
    @file.write({
      'opi' => {
        'kube_config_path' => File.join(Paths::FIXTURES, 'config/opi_kube.conf'),
        'cc_ca_path' => ca_cert_file,
        'cc_cert_path' => client_cert_file,
        'cc_key_path' => client_key_file,
        'nats_ip' => '127.0.0.1',
        'nats_port' => 4222,
        'nats_password' => 'nats',
        'loggregator_ca_path' => ca_cert_file,
        'loggregator_cert_path' => client_cert_file,
        'loggregator_key_path' => client_key_file,
        'tls_port' => tls_port,
        'client_ca_path' => ca_cert_file,
        'server_cert_path' => client_cert_file,
        'server_key_path' => client_key_file
      }
    }.to_yaml)
    @file.close

    @opi_pid = Process.spawn('opi', 'connect', '-c', @file.path)

    wait_for { up?(opi_url) }.to be_truthy
  end

  after do
    Process.kill('SIGTERM', @opi_pid)
    Process.kill('SIGTERM', @nats_pid)
  end

  context 'OPI system tests' do
    context 'when connecting to OPI with a valid client cert' do
      it 'connects successfully' do
        expect(up?(opi_url)).to_not be_nil
      end
    end

    context 'when connecting to OPI with an invalid client cert' do
      let(:client_cert_file) { File.join(Paths::FIXTURES, 'certs/dea_client.crt') }
      let(:client_key_file) { File.join(Paths::FIXTURES, 'certs/dea_client.key') }

      it 'returns a TLS error' do
        expect { client.get(opi_url) }.to raise_error(OpenSSL::SSL::SSLError)
      end
    end
  end
end
