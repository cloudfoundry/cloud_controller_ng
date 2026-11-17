require 'spec_helper'
require 'messages/validators/broker_egress_validator'

module VCAP::CloudController::Validators
  RSpec.describe BrokerEgressValidator do
    let(:record_class) do
      Class.new do
        include ActiveModel::Model

        validates_with BrokerEgressValidator
        attr_accessor :url
      end
    end

    subject(:record) { record_class.new(url: url) }

    let(:public_ip_result) { [['AF_INET', nil, nil, '1.2.3.4', nil, nil, nil]] }
    let(:private_ip_result) { [['AF_INET', nil, nil, '10.0.0.1', nil, nil, nil]] }

    before do
      allow(VCAP::CloudController::Config).to receive(:config).and_return(
        instance_double(VCAP::CloudController::Config, get: nil)
      )
    end

    context 'when URL resolves to a public address' do
      let(:url) { 'https://broker.example.com' }

      before do
        allow(Socket).to receive(:getaddrinfo).and_return(public_ip_result)
      end

      it 'is valid' do
        expect(record).to be_valid
      end
    end

    context 'when URL resolves to a private address' do
      let(:url) { 'https://private.internal' }

      before do
        allow(Socket).to receive(:getaddrinfo).and_return(private_ip_result)
      end

      it 'adds the blocked-address error' do
        expect(record).not_to be_valid
        expect(record.errors[:url]).to include('must not resolve to a private or reserved IP address')
      end
    end

    context 'when URL resolves to mixed allowed/denied addresses' do
      let(:url) { 'https://mixed.example.com' }

      before do
        allow(Socket).to receive(:getaddrinfo).and_return(
          [['AF_INET', nil, nil, '1.2.3.4', nil, nil, nil], ['AF_INET', nil, nil, '10.0.0.1', nil, nil, nil]]
        )
      end

      it 'adds the blocked-address error' do
        expect(record).not_to be_valid
        expect(record.errors[:url]).to include('must not resolve to a private or reserved IP address')
      end
    end

    context 'when host cannot be resolved (SocketError)' do
      let(:url) { 'https://unresolvable.example.com' }

      before do
        allow(Socket).to receive(:getaddrinfo).and_raise(SocketError, 'getaddrinfo failed')
      end

      it 'adds the resolution-failure error' do
        expect(record).not_to be_valid
        expect(record.errors[:url]).to include('Host could not be resolved')
      end
    end

    context 'when resolution returns empty results' do
      let(:url) { 'https://empty.example.com' }

      before do
        allow(Socket).to receive(:getaddrinfo).and_return([])
      end

      it 'adds the resolution-failure error' do
        expect(record).not_to be_valid
        expect(record.errors[:url]).to include('Host could not be resolved')
      end
    end

    context 'when URL already has structural errors (prior url errors)' do
      let(:record_class_with_prior_error) do
        Class.new do
          include ActiveModel::Model

          validate :inject_url_error
          validates_with BrokerEgressValidator
          attr_accessor :url

          def inject_url_error
            errors.add(:url, 'is structurally invalid')
          end
        end
      end

      let(:url) { 'https://broker.example.com' }

      it 'skips resolution and does not call Socket.getaddrinfo' do
        expect(Socket).not_to receive(:getaddrinfo)
        record_class_with_prior_error.new(url: url).valid?
      end
    end

    context 'when URL is an approved private origin' do
      let(:url) { 'https://private.internal:8443' }

      before do
        allow(VCAP::CloudController::Config).to receive(:config).and_return(
          instance_double(VCAP::CloudController::Config).tap do |c|
            allow(c).to receive(:get).with(:broker_egress_allowed_private_destinations).
              and_return([{ 'origin' => 'https://private.internal:8443', 'cidrs' => ['10.0.0.0/24'] }])
            allow(c).to receive(:get).with(:broker_egress_blocked_nat64_prefixes).and_return(nil)
          end
        )
        allow(Socket).to receive(:getaddrinfo).and_return(
          [['AF_INET', nil, nil, '10.0.0.5', nil, nil, nil]]
        )
      end

      it 'is valid' do
        expect(record).to be_valid
      end
    end

    context 'when URL is invalid (BrokerUrl::InvalidUrl)' do
      let(:url) { 'not-a-url' }

      before { expect(Socket).not_to receive(:getaddrinfo) }

      it 'adds a structural url error' do
        expect(record).not_to be_valid
        expect(record.errors[:url]).to eq(['url must use https'])
      end
    end

    context 'when the URL is HTTP or carries credentials' do
      it 'rejects http without resolving DNS' do
        expect(Socket).not_to receive(:getaddrinfo)
        expect(record_class.new(url: 'http://broker.example.com')).not_to be_valid
      end

      it 'does not reflect credentials in the error' do
        expect(Socket).not_to receive(:getaddrinfo)
        r = record_class.new(url: 'https://admin:hunter2@broker.example.com')
        expect(r).not_to be_valid
        expect(r.errors[:url].join).not_to include('hunter2')
      end
    end
  end
end
