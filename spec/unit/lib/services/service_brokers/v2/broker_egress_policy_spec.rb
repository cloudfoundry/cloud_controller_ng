require 'spec_helper'
require 'services/service_brokers/v2/broker_egress_policy'
require 'services/service_brokers/v2/broker_url'

module VCAP::Services::ServiceBrokers::V2
  RSpec.describe BrokerEgressPolicy do
    let(:public_url)  { BrokerUrl.parse!('https://broker.example.com') }
    let(:private_url) { BrokerUrl.parse!('https://private.internal') }

    def policy(allowed=[])
      described_class.new(allowed)
    end

    def stub_resolution(hostname, addresses)
      allow(Socket).to receive(:getaddrinfo).with(hostname, nil, Socket::AF_UNSPEC, Socket::SOCK_STREAM).
        and_return(addresses.map { |a| [nil, nil, nil, a, nil, nil, nil] })
    end

    describe '#resolve_and_validate!' do
      context 'public address' do
        before { stub_resolution('broker.example.com', ['1.2.3.4']) }

        it 'returns a ValidatedDestination' do
          result = policy.resolve_and_validate!(public_url)
          expect(result.addresses).to eq(['1.2.3.4'])
          expect(result.origin).to eq('https://broker.example.com')
          expect(result.port).to eq(443)
        end

        it 'freezes the result' do
          expect(policy.resolve_and_validate!(public_url)).to be_frozen
        end
      end

      context 'private address without exception' do
        before { stub_resolution('private.internal', ['10.0.0.1']) }

        it 'raises DestinationDenied' do
          expect { policy.resolve_and_validate!(private_url) }.to raise_error(BrokerEgressPolicy::DestinationDenied)
        end
      end

      context 'mixed allowed/denied DNS answer' do
        before { stub_resolution('broker.example.com', ['1.2.3.4', '10.0.0.1']) }

        it 'raises DestinationDenied even though first address is allowed' do
          expect { policy.resolve_and_validate!(public_url) }.to raise_error(BrokerEgressPolicy::DestinationDenied)
        end
      end

      context 'approved private exception' do
        let(:allowed) do
          [{ 'origin' => 'https://private.internal', 'cidrs' => ['10.0.0.0/24'] }]
        end

        before { stub_resolution('private.internal', ['10.0.0.5']) }

        it 'allows the address within the exception CIDR' do
          expect { policy(allowed).resolve_and_validate!(private_url) }.not_to raise_error
        end
      end

      context 'exception with address outside CIDR' do
        let(:allowed) do
          [{ 'origin' => 'https://private.internal', 'cidrs' => ['10.0.0.0/24'] }]
        end

        before { stub_resolution('private.internal', ['10.0.1.1']) }

        it 'raises DestinationDenied' do
          expect { policy(allowed).resolve_and_validate!(private_url) }.to raise_error(BrokerEgressPolicy::DestinationDenied)
        end
      end

      context 'exception does not apply to different origin' do
        let(:allowed) do
          [{ 'origin' => 'https://other.internal', 'cidrs' => ['10.0.0.0/24'] }]
        end

        before { stub_resolution('private.internal', ['10.0.0.5']) }

        it 'raises DestinationDenied' do
          expect { policy(allowed).resolve_and_validate!(private_url) }.to raise_error(BrokerEgressPolicy::DestinationDenied)
        end
      end

      context 'always-blocked ranges ignored by exceptions' do
        let(:loopback_url) { BrokerUrl.parse!('https://loopback.example.com') }
        let(:allowed) do
          [{ 'origin' => 'https://loopback.example.com', 'cidrs' => ['10.0.0.0/8'] }]
        end

        before { stub_resolution('loopback.example.com', ['127.0.0.1']) }

        it 'still raises DestinationDenied for loopback even with CIDR exception' do
          # loopback is an always-blocked range; CIDRs can only be RFC1918/ULA/shared
          # BlockedIpRanges.blocked? returns true for 127.0.0.1 regardless
          expect { policy(allowed).resolve_and_validate!(loopback_url) }.to raise_error(BrokerEgressPolicy::DestinationDenied)
        end
      end

      context 'resolution failures' do
        it 'raises ResolutionFailed(:empty_result) for empty DNS answer' do
          stub_resolution('broker.example.com', [])
          expect { policy.resolve_and_validate!(public_url) }.
            to raise_error(BrokerEgressPolicy::ResolutionFailed) { |e| expect(e.reason).to eq(:empty_result) }
        end

        it 'raises ResolutionFailed(:socket_error) for SocketError during resolution' do
          allow(Socket).to receive(:getaddrinfo).and_raise(SocketError, 'getaddrinfo failed')
          expect { policy.resolve_and_validate!(public_url) }.
            to raise_error(BrokerEgressPolicy::ResolutionFailed) { |e| expect(e.reason).to eq(:socket_error) }
        end
      end

      context 'IPv6 ULA blocked by default' do
        let(:ula_url) { BrokerUrl.parse!('https://ula.example.com') }

        before { stub_resolution('ula.example.com', ['fd00::1']) }

        it 'raises DestinationDenied' do
          expect { policy.resolve_and_validate!(ula_url) }.to raise_error(BrokerEgressPolicy::DestinationDenied)
        end
      end

      context 'IPv4-mapped IPv6 blocked' do
        let(:mapped_url) { BrokerUrl.parse!('https://mapped.example.com') }

        before { stub_resolution('mapped.example.com', ['::ffff:127.0.0.1']) }

        it 'raises DestinationDenied' do
          expect { policy.resolve_and_validate!(mapped_url) }.to raise_error(BrokerEgressPolicy::DestinationDenied)
        end
      end
    end

    describe 'ResolutionFailed' do
      it 'carries a read-only reason' do
        err = BrokerEgressPolicy::ResolutionFailed.new(:timeout)
        expect(err.reason).to eq(:timeout)
        expect { err.reason = :other }.to raise_error(NoMethodError)
      end
    end

    describe 'constructor with invalid exception entries' do
      it 'skips entries with malformed origins without raising' do
        allowed = [{ 'origin' => 'not-a-url', 'cidrs' => ['10.0.0.0/8'] }]
        expect { policy(allowed) }.not_to raise_error
      end

      it 'skips entries missing origin key' do
        allowed = [{ 'cidrs' => ['10.0.0.0/8'] }]
        expect { policy(allowed) }.not_to raise_error
      end

      it 'skips entries with non-array cidrs' do
        allowed = [{ 'origin' => 'https://broker.example.com', 'cidrs' => '10.0.0.0/8' }]
        expect { policy(allowed) }.not_to raise_error
      end
    end
  end
end
