require 'spec_helper'
require 'services/service_brokers/v2/broker_url'

module VCAP::Services::ServiceBrokers::V2
  RSpec.describe BrokerUrl do
    describe '.parse!' do
      subject(:parse) { described_class.parse!(url) }

      context 'valid URLs' do
        it 'accepts https' do
          b = described_class.parse!('https://broker.example.com/v2')
          expect(b.scheme).to eq('https')
          expect(b.hostname).to eq('broker.example.com')
          expect(b.port).to eq(443)
          expect(b.origin).to eq('https://broker.example.com')
        end

        it 'accepts non-default port and includes it in origin' do
          b = described_class.parse!('https://broker.example.com:8443/v2')
          expect(b.port).to eq(8443)
          expect(b.origin).to eq('https://broker.example.com:8443')
        end

        it 'normalizes scheme case' do
          b = described_class.parse!('HTTPS://broker.example.com')
          expect(b.scheme).to eq('https')
        end

        it 'accepts bracketed IPv6 with non-default port' do
          b = described_class.parse!('https://[::1]:8443/v2')
          expect(b.hostname).to eq('::1')
          expect(b.port).to eq(8443)
          expect(b.origin).to eq('https://[::1]:8443')
        end

        it 'normalizes host case and deeply freezes the result' do
          b = described_class.parse!('HTTPS://Broker.Example.COM:8443/v2')
          expect(b.hostname).to eq('broker.example.com')
          expect(b.origin).to eq('https://broker.example.com:8443')
          expect([b, b.uri, b.hostname, b.origin, b.scheme, b.uri.host, b.uri.path]).to all(be_frozen)
        end

        it 'treats explicit and default port as the same origin' do
          expect(described_class.parse!('https://a.example.com:443').origin).to eq('https://a.example.com')
        end

        it 'preserves escaped base path' do
          b = described_class.parse!('https://broker.example.com/v2%2Fapi')
          expect(b.uri.path).to eq('/v2%2Fapi')
        end
      end

      context 'invalid URLs' do
        def expect_invalid(url)
          expect { described_class.parse!(url) }.to raise_error(BrokerUrl::InvalidUrl)
        end

        it 'rejects non-string' do
          expect { described_class.parse!(nil) }.to raise_error(BrokerUrl::InvalidUrl)
        end

        it 'rejects relative URL' do
          expect_invalid('/v2/catalog')
        end

        it 'rejects non-https schemes' do
          expect_invalid('ftp://broker.example.com')
          expect_invalid('http://broker.example.com')
          expect_invalid('HTTP://broker.example.com')
        end

        it 'does not echo the input in error messages' do
          expect { described_class.parse!('http://user:secret@broker.example.com') }.
            to raise_error(BrokerUrl::InvalidUrl) { |e| expect(e.message).not_to include('secret') }
          expect { described_class.parse!('https://user:secret@broker .example.com') }.
            to raise_error(BrokerUrl::InvalidUrl) { |e| expect(e.message).not_to include('secret') }
          expect { described_class.parse!('https://user:secret@[bad') }.
            to raise_error(BrokerUrl::InvalidUrl) { |e| expect(e.message).not_to include('secret') }
        end

        it 'rejects unicode whitespace' do
          expect_invalid("https://broker.example.com/a\u00a0b")
        end

        it 'rejects empty hostname' do
          expect_invalid('https://')
        end

        it 'rejects userinfo with password' do
          expect_invalid('https://user:pass@broker.example.com')
        end

        it 'rejects empty username (userinfo present)' do
          expect_invalid('https://:@broker.example.com')
        end

        it 'rejects fragment' do
          expect_invalid('https://broker.example.com#section')
        end

        it 'rejects empty fragment' do
          expect_invalid('https://broker.example.com#')
        end

        it 'rejects #@host-style fragment injection' do
          # URI.parse sees this as host=broker.example.com, fragment=@evil.com
          expect_invalid('https://broker.example.com#@evil.com')
        end

        it 'rejects whitespace' do
          expect_invalid('https://broker.example.com/v2 catalog')
        end

        it 'rejects control characters' do
          expect_invalid("https://broker.example.com\x00/v2")
        end

        it 'rejects port 0' do
          expect_invalid('https://broker.example.com:0/v2')
        end

        it 'rejects port above 65535' do
          expect_invalid('https://broker.example.com:65536/v2')
        end

        it 'rejects invalid authority' do
          expect_invalid('https://[invalid-ipv6/v2')
        end
      end
    end
  end
end
