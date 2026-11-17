require 'spec_helper'
require 'cloud_controller/security/blocked_ip_ranges'

module VCAP::CloudController::Security
  RSpec.describe BlockedIpRanges do
    describe '.blocked?' do
      def blocked(addr) = described_class.blocked?(addr)

      context 'loopback' do
        it { expect(blocked('127.0.0.1')).to be true }
        it { expect(blocked('127.255.255.255')).to be true }
        it { expect(blocked('::1')).to be true }
      end

      context 'link-local / cloud metadata' do
        it { expect(blocked('169.254.0.0')).to be true }
        it { expect(blocked('169.254.169.254')).to be true }
        it { expect(blocked('169.254.255.255')).to be true }
        it { expect(blocked('fe80::1')).to be true }
      end

      context 'RFC1918' do
        it { expect(blocked('10.0.0.0')).to be true }
        it { expect(blocked('10.255.255.255')).to be true }
        it { expect(blocked('172.16.0.0')).to be true }
        it { expect(blocked('172.31.255.255')).to be true }
        it { expect(blocked('192.168.0.0')).to be true }
        it { expect(blocked('192.168.255.255')).to be true }
      end

      context 'unspecified' do
        it { expect(blocked('0.0.0.1')).to be true }
        it { expect(blocked('::')).to be true }
      end

      context 'IPv4-mapped IPv6' do
        it { expect(blocked('::ffff:169.254.169.254')).to be true }
        it { expect(blocked('::ffff:127.0.0.1')).to be true }
      end

      context 'IPv4-compatible IPv6' do
        it { expect(blocked('::127.0.0.1')).to be true }
        it { expect(blocked('::169.254.169.254')).to be true }
      end

      context '6to4' do
        it { expect(blocked('2002:7f00:1::')).to be true }
        it { expect(blocked('2002:a9fe:a9fe::')).to be true } # encodes 169.254.169.254
      end

      context 'IPv6 ULA' do
        it { expect(blocked('fc00::1')).to be true }
        it { expect(blocked('fd00::1')).to be true }
      end

      context 'shared address space' do
        it { expect(blocked('100.64.0.0')).to be true }
        it { expect(blocked('100.127.255.255')).to be true }
      end

      context 'multicast' do
        it { expect(blocked('224.0.0.1')).to be true }
        it { expect(blocked('239.255.255.255')).to be true }
        it { expect(blocked('ff02::1')).to be true }
      end

      context 'limited broadcast' do
        it { expect(blocked('255.255.255.255')).to be true }
      end

      context 'NAT64 well-known prefix' do
        it { expect(blocked('64:ff9b::169.254.169.254')).to be true }
        it { expect(blocked('64:ff9b::10.0.0.1')).to be true }
        it { expect(blocked('64:ff9b::8.8.8.8')).to be true } # public IPv4 via NAT64 — still blocked
      end

      context 'NAT64 local-use prefix' do
        it { expect(blocked('64:ff9b:1::1')).to be true }
        it { expect(blocked('64:ff9b:1:ffff:ffff:ffff:ffff:ffff')).to be true }
        it { expect(blocked('64:ff9b:2::1')).to be false }
      end

      context 'deployment-specific NAT64 prefixes' do
        let(:prefixes) { ['2001:db8:100::/48', '2001:db8:200::/96'] }

        it 'blocks addresses inside configured prefixes (strings or IPAddr)' do
          expect(described_class.blocked?('2001:db8:100:1::1', prefixes)).to be true
          expect(described_class.blocked?('2001:db8:200::1.2.3.4', prefixes.map { |p| IPAddr.new(p) })).to be true
        end

        it 'leaves other public addresses allowed' do
          expect(described_class.blocked?('2001:db8:300::1', prefixes)).to be false
        end

        it 'fails closed on an invalid configured prefix' do
          expect(described_class.blocked?('2001:db8::1', ['bogus'])).to be true
        end
      end

      context 'public addresses (allowed)' do
        it { expect(blocked('8.8.8.8')).to be false }
        it { expect(blocked('1.1.1.1')).to be false }
        it { expect(blocked('2001:4860:4860::8888')).to be false }
        it { expect(blocked('172.15.255.255')).to be false }  # just outside RFC1918
        it { expect(blocked('172.32.0.0')).to be false }      # just outside RFC1918
      end

      context 'adjacent to blocked ranges (allowed)' do
        it { expect(blocked('128.0.0.0')).to be false }       # just outside loopback
        it { expect(blocked('169.253.255.255')).to be false }  # just below link-local
        it { expect(blocked('169.255.0.0')).to be false }      # just above link-local
        it { expect(blocked('100.63.255.255')).to be false }   # just below shared space
        it { expect(blocked('100.128.0.0')).to be false }      # just above shared space
      end

      context 'invalid input fails closed' do
        it { expect(blocked('not-an-ip')).to be true }
        it { expect(blocked('')).to be true }
        it { expect(blocked('999.999.999.999')).to be true }
      end
    end

    describe '.parse_nat64_prefix!' do
      %w[2001:db8::/32 2001:db8::/40 2001:db8::/48 2001:db8::/56 2001:db8::/64 2001:db8::/96].each do |prefix|
        it("accepts #{prefix}") { expect(described_class.parse_nat64_prefix!(prefix)).to be_a(IPAddr) }
      end

      ['2001:db8::/33', '2001:db8::/0', '2001:db8::/128', '10.0.0.0/8', '2001:db8::', '2001:db8::/48/1', 'fe80::1%eth0/64', 'x', '', nil, 48].each do |bad|
        it("rejects #{bad.inspect}") do
          expect { described_class.parse_nat64_prefix!(bad) }.to raise_error(described_class::InvalidNat64Prefix)
        end
      end
    end
  end
end
