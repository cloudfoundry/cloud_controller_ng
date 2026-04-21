require 'rspec'
require 'loggregator_emitter/client'

RSpec.describe LoggregatorEmitter::Client do
  let(:stub) { instance_double(Loggregator::V2::Ingress::Stub) }

  describe '#initialize' do
    let(:endpoint) { 'localhost:1234' }
    let(:origin) { 'cloud_controller' }
    let(:source_type) { 'API' }
    let(:instance_id) { 0 }

    it 'raises ArgumentError when endpoint is empty' do
      expect do
        described_class.new(endpoint: '', origin: origin, source_type: source_type, instance_id: instance_id)
      end.to raise_error(ArgumentError, 'Must provide a valid endpoint')
    end

    it 'raises ArgumentError when endpoint is nil' do
      expect do
        described_class.new(endpoint: nil, origin: origin, source_type: source_type, instance_id: instance_id)
      end.to raise_error(ArgumentError, 'Must provide a valid endpoint')
    end

    it 'raises ArgumentError when origin is nil' do
      expect do
        described_class.new(endpoint: endpoint, origin: nil, source_type: source_type, instance_id: instance_id)
      end.to raise_error(ArgumentError, 'Must provide a valid origin')
    end

    it 'raises ArgumentError when source_type is nil' do
      expect do
        described_class.new(endpoint: endpoint, origin: origin, source_type: nil, instance_id: instance_id)
      end.to raise_error(ArgumentError, 'Must provide a valid source_type')
    end

    it 'creates a client with valid arguments' do
      expect do
        described_class.new(endpoint: endpoint, origin: origin, source_type: source_type, instance_id: instance_id)
      end.not_to raise_error
    end
  end

  describe '#emit' do
    subject(:client) do
      described_class.new(endpoint: 'localhost:1234', origin: 'cloud_controller', source_type: 'API', instance_id: 0)
    end

    before do
      allow(Loggregator::V2::Ingress::Stub).to receive(:new).and_return(stub)
      allow(stub).to receive(:send)
    end

    it 'sends an envelope with OUT type' do
      client.emit('app-guid-123', 'some log message')
      expect(stub).to have_received(:send) do |batch|
        envelope = batch.batch.first
        expect(envelope.source_id).to eq('app-guid-123')
        expect(envelope.log.type).to eq(:OUT)
        expect(envelope.log.payload).to eq('some log message')
      end
    end
  end

  describe '#emit_error' do
    subject(:client) do
      described_class.new(endpoint: 'localhost:1234', origin: 'cloud_controller', source_type: 'API', instance_id: 0)
    end

    before do
      allow(Loggregator::V2::Ingress::Stub).to receive(:new).and_return(stub)
      allow(stub).to receive(:send)
    end

    it 'sends an envelope with ERR type' do
      client.emit_error('app-guid-123', 'some error message')
      expect(stub).to have_received(:send) do |batch|
        envelope = batch.batch.first
        expect(envelope.source_id).to eq('app-guid-123')
        expect(envelope.log.type).to eq(:ERR)
        expect(envelope.log.payload).to eq('some error message')
      end
    end
  end

  describe 'credentials' do
    before do
      allow(Loggregator::V2::Ingress::Stub).to receive(:new).and_return(stub)
      allow(stub).to receive(:send)
    end

    it 'uses insecure credentials when no cert files are provided' do
      client = described_class.new(endpoint: 'localhost:1234', origin: 'cloud_controller', source_type: 'API', instance_id: 0)
      client.emit('app-guid-123', 'message')
      expect(Loggregator::V2::Ingress::Stub).to have_received(:new).with('localhost:1234', :this_channel_is_insecure,
                                                                         channel_args: {}, timeout: 10)
    end

    it 'uses TLS credentials when all cert files are provided' do
      tls_creds = instance_double(GRPC::Core::ChannelCredentials)
      allow(File).to receive(:read).with('/certs/ca.crt').and_return('ca-cert-content')
      allow(File).to receive(:read).with('/certs/client.key').and_return('client-key-content')
      allow(File).to receive(:read).with('/certs/client.crt').and_return('client-cert-content')
      allow(GRPC::Core::ChannelCredentials).to receive(:new).and_return(tls_creds)

      client = described_class.new(
        endpoint: 'localhost:1234',
        origin: 'cloud_controller',
        source_type: 'API',
        instance_id: 0,
        ca_cert_file: '/certs/ca.crt',
        client_cert_file: '/certs/client.crt',
        client_key_file: '/certs/client.key',
        subject_name: 'metron'
      )
      client.emit('app-guid-123', 'message')

      expect(GRPC::Core::ChannelCredentials).to have_received(:new).with('ca-cert-content', 'client-key-content', 'client-cert-content')
      expect(Loggregator::V2::Ingress::Stub).to have_received(:new).with('localhost:1234', tls_creds, channel_args: { 'grpc.ssl_target_name_override': 'metron' },
                                                                                                      timeout: 10)
    end
  end
end
