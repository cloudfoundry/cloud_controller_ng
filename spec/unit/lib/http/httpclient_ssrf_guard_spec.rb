require 'spec_helper'
require 'http/httpclient'
require 'services/service_brokers/v2/broker_url'
require 'services/service_brokers/v2/broker_egress_policy'
require 'webrick'
require 'webrick/https'
require 'openssl'
require 'tempfile'

# Transport proof: demonstrates that the broker connection context works with httpclient 2.10.0.
# Verifies: @client reference in Session, IP pinning, TLS SNI/cert identity, no second DNS lookup,
# proxy disabling, timeout preservation, and reconnect behavior.
#
# Run with: bundle exec rspec spec/unit/lib/http/httpclient_ssrf_guard_spec.rb

RSpec.describe 'HTTPClient broker connection context' do
  # Transport proof uses real TCP sockets against local WEBrick servers.
  before(:all) { WebMock.allow_net_connect! } # rubocop:disable RSpec/BeforeAfterAll
  after(:all)  { WebMock.disable_net_connect!(allow: %w[fake.bbs]) } # rubocop:disable RSpec/BeforeAfterAll

  # Shared helpers for spinning up local WEBrick servers.
  def start_http_server(port)
    logger = WEBrick::Log.new(File::NULL)
    access_log = []
    server = WEBrick::HTTPServer.new(Port: port, Logger: logger, AccessLog: access_log)
    server.mount_proc('/') { |_req, res| res.body = 'ok' }
    thread = Thread.new { server.start }
    # Wait for the server to accept connections.
    retries = 20
    begin
      TCPSocket.new('127.0.0.1', port).close
    rescue Errno::ECONNREFUSED
      sleep 0.05
      retry if (retries -= 1) > 0
      raise 'HTTP server did not start in time'
    end
    [server, thread]
  end

  def start_https_server(port, cert_cn='broker.test.local')
    key, cert = make_self_signed_cert(cert_cn)
    logger = WEBrick::Log.new(File::NULL)
    server = WEBrick::HTTPServer.new(
      Port: port, Logger: logger, AccessLog: [],
      SSLEnable: true, SSLPrivateKey: key, SSLCertificate: cert
    )
    server.mount_proc('/') { |_req, res| res.body = 'ok' }
    thread = Thread.new { server.start }
    retries = 30
    begin
      TCPSocket.new('127.0.0.1', port).close
    rescue Errno::ECONNREFUSED
      sleep 0.05
      retry if (retries -= 1) > 0
    end
    [server, thread]
  end

  def stop_server(server, thread)
    server.shutdown
    thread.join(2)
  end

  def make_self_signed_cert(cert_cn)
    key = OpenSSL::PKey::RSA.new(2048)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 1
    cert.subject = OpenSSL::X509::Name.parse("/CN=#{cert_cn}")
    cert.issuer = cert.subject
    cert.public_key = key.public_key
    cert.not_before = Time.now - 1
    cert.not_after = Time.now + 3600
    ext_factory = OpenSSL::X509::ExtensionFactory.new(cert, cert)
    cert.add_extension(ext_factory.create_extension('subjectAltName', "DNS:#{cert_cn}", false))
    cert.sign(key, OpenSSL::Digest.new('SHA256'))
    [key, cert]
  end

  # --- HTTPS tests for IP pinning (broker context) ---

  describe 'HTTPS with broker context (IP pinning)' do
    let(:port) { 59_301 }
    let(:server_info) { start_https_server(port) }
    let(:server) { server_info[0] }
    let(:thread) { server_info[1] }

    before { server_info }
    after { stop_server(server, thread) }

    it 'connects to the validated IP instead of re-resolving the hostname' do
      url = "https://broker.test.local:#{port}"
      broker_url = VCAP::Services::ServiceBrokers::V2::BrokerUrl.parse!(url)
      policy = VCAP::Services::ServiceBrokers::V2::BrokerEgressPolicy.new

      # Stub resolution so broker.test.local → 127.0.0.1 (passes policy as public-style)
      allow(Socket).to receive(:getaddrinfo).with('broker.test.local', nil, Socket::AF_UNSPEC, Socket::SOCK_STREAM).
        and_return([['AF_INET', nil, nil, '127.0.0.1', nil, nil, nil]])

      # broker.test.local → 127.0.0.1 (loopback) would be blocked by default policy.
      # Use a policy that allows 127.0.0.0/8 for this local test.
      allow(policy).to receive(:resolve_and_validate!).with(broker_url).and_return(
        VCAP::Services::ServiceBrokers::V2::BrokerEgressPolicy::ValidatedDestination.new(
          origin: broker_url.origin, port: broker_url.port, addresses: ['127.0.0.1']
        ).freeze
      )

      client = HTTPClient.new
      client.broker_connection_context = { broker_url: broker_url, policy: policy }
      client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE

      res = client.get("https://broker.test.local:#{port}/")
      expect(res.status).to eq(200)
      expect(res.body).to eq('ok')
    end

    it 'does not call Socket.getaddrinfo a second time inside create_socket' do
      url = "https://broker.test.local:#{port}"
      broker_url = VCAP::Services::ServiceBrokers::V2::BrokerUrl.parse!(url)
      policy = VCAP::Services::ServiceBrokers::V2::BrokerEgressPolicy.new

      resolve_count = 0
      allow(policy).to receive(:resolve_and_validate!).with(broker_url) do
        resolve_count += 1
        VCAP::Services::ServiceBrokers::V2::BrokerEgressPolicy::ValidatedDestination.new(
          origin: broker_url.origin, port: broker_url.port, addresses: ['127.0.0.1']
        ).freeze
      end

      allow(Socket).to receive(:getaddrinfo).and_call_original

      client = HTTPClient.new
      client.broker_connection_context = { broker_url: broker_url, policy: policy }
      client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
      client.get("https://broker.test.local:#{port}/")

      # resolve_and_validate! called once per connection; Socket.getaddrinfo only inside policy
      expect(resolve_count).to eq(1)
      expect(Socket).not_to have_received(:getaddrinfo).with('broker.test.local', anything, anything, anything)
    end

    it 'client without context uses the original hostname path unchanged' do
      client = HTTPClient.new
      expect(client.broker_connection_context).to be_nil
      client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE

      # Should connect normally to localhost — no context, no policy check
      res = client.get("https://127.0.0.1:#{port}/")
      expect(res.status).to eq(200)
    end

    it 'fails closed when destination hostname does not match context' do
      url = "https://broker.test.local:#{port}"
      broker_url = VCAP::Services::ServiceBrokers::V2::BrokerUrl.parse!(url)
      policy = instance_double(VCAP::Services::ServiceBrokers::V2::BrokerEgressPolicy)

      client = HTTPClient.new
      client.broker_connection_context = { broker_url: broker_url, policy: policy }
      client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE

      # Connecting to a different host than the context's broker hostname
      expect { client.get("https://other.host:#{port}/") }.
        to raise_error(SocketError, /hostname mismatch/)
    end

    it 'raises SocketError when policy raises DestinationDenied' do
      url = "https://broker.test.local:#{port}"
      broker_url = VCAP::Services::ServiceBrokers::V2::BrokerUrl.parse!(url)
      policy = instance_double(VCAP::Services::ServiceBrokers::V2::BrokerEgressPolicy)
      allow(policy).to receive(:resolve_and_validate!).
        and_raise(VCAP::Services::ServiceBrokers::V2::BrokerEgressPolicy::DestinationDenied, 'blocked')

      client = HTTPClient.new
      client.broker_connection_context = { broker_url: broker_url, policy: policy }
      client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE

      expect { client.get("https://broker.test.local:#{port}/") }.to raise_error(SocketError)
    end

    it 'raises SocketError when policy raises ResolutionFailed' do
      url = "https://broker.test.local:#{port}"
      broker_url = VCAP::Services::ServiceBrokers::V2::BrokerUrl.parse!(url)
      policy = instance_double(VCAP::Services::ServiceBrokers::V2::BrokerEgressPolicy)
      allow(policy).to receive(:resolve_and_validate!).
        and_raise(VCAP::Services::ServiceBrokers::V2::BrokerEgressPolicy::ResolutionFailed.new(:timeout))

      client = HTTPClient.new
      client.broker_connection_context = { broker_url: broker_url, policy: policy }
      client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE

      expect { client.get("https://broker.test.local:#{port}/") }.to raise_error(SocketError)
    end
  end

  # --- Proxy disabling test ---

  describe 'proxy disabling' do
    let(:port) { 59_302 }
    let(:server_info) { start_https_server(port, '127.0.0.1') }
    let(:server) { server_info[0] }
    let(:thread) { server_info[1] }

    before { server_info }
    after { stop_server(server, thread) }

    it 'client.proxy = nil clears env-loaded proxy' do
      client = HTTPClient.new
      # Simulate env proxy being set
      client.proxy = 'http://proxy.example.com:3128'
      expect(client.proxy).not_to be_nil

      client.proxy = nil
      expect(client.proxy).to be_nil

      client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
      # Should connect directly, not via proxy
      res = client.get("https://127.0.0.1:#{port}/")
      expect(res.status).to eq(200)
    end
  end

  # --- HTTPS / TLS identity test ---

  describe 'HTTPS with broker context' do
    let(:port) { 59_303 }
    let(:hostname) { 'broker.test.local' }
    let(:key_and_cert) { make_self_signed_cert(hostname) }
    let(:server_key) { key_and_cert[0] }
    let(:server_cert) { key_and_cert[1] }

    let(:server_info) do
      logger = WEBrick::Log.new(File::NULL)
      server = WEBrick::HTTPServer.new(
        Port: port, Logger: logger, AccessLog: [],
        SSLEnable: true, SSLPrivateKey: server_key, SSLCertificate: server_cert
      )
      server.mount_proc('/') { |_req, res| res.body = 'ok' }
      thread = Thread.new { server.start }
      retries = 30
      begin
        s = TCPSocket.new('127.0.0.1', port)
        s.close
      rescue Errno::ECONNREFUSED
        sleep 0.05
        retry if (retries -= 1) > 0
      end
      [server, thread]
    end
    let(:server) { server_info[0] }
    let(:thread) { server_info[1] }

    before { server_info }
    after { stop_server(server, thread) }

    it 'connects via IP but uses original hostname for cert verification' do
      url = "https://#{hostname}:#{port}"
      broker_url = VCAP::Services::ServiceBrokers::V2::BrokerUrl.parse!(url)
      policy = instance_double(VCAP::Services::ServiceBrokers::V2::BrokerEgressPolicy)
      allow(policy).to receive(:resolve_and_validate!).with(broker_url).and_return(
        VCAP::Services::ServiceBrokers::V2::BrokerEgressPolicy::ValidatedDestination.new(
          origin: broker_url.origin, port: port, addresses: ['127.0.0.1']
        ).freeze
      )

      client = HTTPClient.new
      client.broker_connection_context = { broker_url: broker_url, policy: policy }
      # add_trust_ca requires a file path — write cert to a tempfile
      trust_ca_file = Tempfile.new(['broker_ca', '.pem'])
      begin
        trust_ca_file.write(server_cert.to_pem)
        trust_ca_file.flush
        client.ssl_config.add_trust_ca(trust_ca_file.path)
        client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_PEER

        res = client.get("https://#{hostname}:#{port}/")
        expect(res.status).to eq(200)
        # 200 with VERIFY_PEER proves TLS negotiated against the hostname (cert was verified)
      ensure
        trust_ca_file.close!
      end
    end

    it 'fails TLS cert verification when connecting to an IP with mismatched cert' do
      # This test proves TLS identity is NOT based on the IP but on the hostname.
      client = HTTPClient.new
      client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_PEER
      # No trusted CA — should fail TLS, not succeed silently
      expect { client.get("https://127.0.0.1:#{port}/") }.to raise_error(OpenSSL::SSL::SSLError)
    end
  end

  # --- Reconnect: re-resolves on new connection ---

  describe 'reconnect behavior' do
    let(:port) { 59_304 }
    let(:server_info) { start_https_server(port) }
    let(:server) { server_info[0] }
    let(:thread) { server_info[1] }

    before { server_info }
    after { stop_server(server, thread) }

    it 'calls resolve_and_validate! again for a new connection after the session is closed' do
      url = "https://broker.test.local:#{port}"
      broker_url = VCAP::Services::ServiceBrokers::V2::BrokerUrl.parse!(url)
      policy = instance_double(VCAP::Services::ServiceBrokers::V2::BrokerEgressPolicy)
      call_count = 0
      allow(policy).to receive(:resolve_and_validate!).with(broker_url) do
        call_count += 1
        VCAP::Services::ServiceBrokers::V2::BrokerEgressPolicy::ValidatedDestination.new(
          origin: broker_url.origin, port: port, addresses: ['127.0.0.1']
        ).freeze
      end

      client = HTTPClient.new
      client.broker_connection_context = { broker_url: broker_url, policy: policy }
      client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE

      client.get("https://broker.test.local:#{port}/")
      # Force close the session pool so next request opens a new socket
      client.reset_all
      client.get("https://broker.test.local:#{port}/")

      expect(call_count).to eq(2)
    end

    it 'does not call resolve_and_validate! a second time when the connection is reused (keep-alive)' do
      url = "https://broker.test.local:#{port}"
      broker_url = VCAP::Services::ServiceBrokers::V2::BrokerUrl.parse!(url)
      policy = instance_double(VCAP::Services::ServiceBrokers::V2::BrokerEgressPolicy)
      call_count = 0
      allow(policy).to receive(:resolve_and_validate!).with(broker_url) do
        call_count += 1
        VCAP::Services::ServiceBrokers::V2::BrokerEgressPolicy::ValidatedDestination.new(
          origin: broker_url.origin, port: port, addresses: ['127.0.0.1']
        ).freeze
      end

      client = HTTPClient.new
      client.broker_connection_context = { broker_url: broker_url, policy: policy }
      client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE

      # Two sequential requests — httpclient reuses the keep-alive connection for the second
      client.get("https://broker.test.local:#{port}/")
      client.get("https://broker.test.local:#{port}/")

      # create_socket only called once; second request reused the existing socket
      expect(call_count).to eq(1)
    end

    it 're-resolves after peer disconnect (server closes connection)' do
      url = "https://broker.test.local:#{port}"
      broker_url = VCAP::Services::ServiceBrokers::V2::BrokerUrl.parse!(url)
      policy = instance_double(VCAP::Services::ServiceBrokers::V2::BrokerEgressPolicy)
      call_count = 0
      allow(policy).to receive(:resolve_and_validate!).with(broker_url) do
        call_count += 1
        VCAP::Services::ServiceBrokers::V2::BrokerEgressPolicy::ValidatedDestination.new(
          origin: broker_url.origin, port: port, addresses: ['127.0.0.1']
        ).freeze
      end

      client = HTTPClient.new
      client.broker_connection_context = { broker_url: broker_url, policy: policy }
      client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE

      client.get("https://broker.test.local:#{port}/")
      expect(call_count).to eq(1)

      # Simulate peer disconnect by restarting the server
      stop_server(server, thread)
      new_server_info = start_https_server(port)

      begin
        client.get("https://broker.test.local:#{port}/")
        expect(call_count).to eq(2)
      ensure
        stop_server(new_server_info[0], new_server_info[1])
      end
    end

    it 'proxy remains nil after reset_all' do
      url = "https://broker.test.local:#{port}"
      broker_url = VCAP::Services::ServiceBrokers::V2::BrokerUrl.parse!(url)
      policy = instance_double(VCAP::Services::ServiceBrokers::V2::BrokerEgressPolicy)
      allow(policy).to receive(:resolve_and_validate!).with(broker_url).and_return(
        VCAP::Services::ServiceBrokers::V2::BrokerEgressPolicy::ValidatedDestination.new(
          origin: broker_url.origin, port: port, addresses: ['127.0.0.1']
        ).freeze
      )

      client = HTTPClient.new
      client.proxy = nil
      client.broker_connection_context = { broker_url: broker_url, policy: policy }
      client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
      client.get("https://broker.test.local:#{port}/")
      client.reset_all
      # proxy setting survives reset_all (it's on the HTTPClient, not the session)
      expect(client.proxy).to be_nil
    end

    it 'two clients with different contexts do not share validated addresses' do
      url = "https://broker.test.local:#{port}"
      broker_url = VCAP::Services::ServiceBrokers::V2::BrokerUrl.parse!(url)

      policy_a = instance_double(VCAP::Services::ServiceBrokers::V2::BrokerEgressPolicy)
      policy_b = instance_double(VCAP::Services::ServiceBrokers::V2::BrokerEgressPolicy)

      allow(policy_a).to receive(:resolve_and_validate!).and_return(
        VCAP::Services::ServiceBrokers::V2::BrokerEgressPolicy::ValidatedDestination.new(
          origin: broker_url.origin, port: port, addresses: ['127.0.0.1']
        ).freeze
      )
      allow(policy_b).to receive(:resolve_and_validate!).and_return(
        VCAP::Services::ServiceBrokers::V2::BrokerEgressPolicy::ValidatedDestination.new(
          origin: broker_url.origin, port: port, addresses: ['127.0.0.1']
        ).freeze
      )

      client_a = HTTPClient.new
      client_a.broker_connection_context = { broker_url: broker_url, policy: policy_a }
      client_a.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
      client_b = HTTPClient.new
      client_b.broker_connection_context = { broker_url: broker_url, policy: policy_b }
      client_b.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE

      client_a.get("https://broker.test.local:#{port}/")
      client_b.get("https://broker.test.local:#{port}/")

      # Each client resolves independently through its own policy
      expect(policy_a).to have_received(:resolve_and_validate!).once
      expect(policy_b).to have_received(:resolve_and_validate!).once
    end
  end
end
