require 'spec_helper'

module CloudController
  RSpec.describe RuleValidator do
    describe '.validate_destination' do
      subject { described_class.validate_destination(destination) }

      before do
        TestConfig.override(
          enable_ipv6: true,
          security_groups: { enable_comma_delimited_destinations: false }
        )
      end

      context 'with a single valid IPv4 address' do
        let(:destination) { '192.168.10.2' }

        it { is_expected.to be true }
      end

      context 'with a valid CIDR' do
        let(:destination) { '10.0.0.0/8' }

        it { is_expected.to be true }
      end

      context 'with a valid ascending range' do
        let(:destination) { '192.168.10.2-192.168.15.254' }

        it { is_expected.to be true }
      end

      context 'with an inverted range' do
        let(:destination) { '200.0.0.0-150.0.0.0' }

        it { is_expected.to be false }
      end

      context 'with a range whose second endpoint is a CIDR' do
        let(:destination) { '1.1.1.1-2.2.2.2/30' }

        it { is_expected.to be false }
      end

      context 'with a malformed address' do
        let(:destination) { '999.999.999.999' }

        it { is_expected.to be false }
      end

      # Zero-padded IPv4 octets are ambiguous (decimal vs. octal) and are rejected downstream by Diego and vxlan-policy-agent.
      context 'with leading zeros in an IPv4 address' do
        context 'in the first octet' do
          let(:destination) { '010.0.0.53' }

          it { is_expected.to be false }
        end

        context 'in every octet' do
          let(:destination) { '03.005.010.02' }

          it { is_expected.to be false }
        end

        context 'in a CIDR' do
          let(:destination) { '010.000.000.000/24' }

          it { is_expected.to be false }
        end

        context 'in a range endpoint' do
          let(:destination) { '010.0.0.1-10.0.0.9' }

          it { is_expected.to be false }
        end
      end

      context 'with a valid IPv6 address' do
        let(:destination) { '2001:db8::1' }

        it { is_expected.to be true }
      end

      # Zero-padded IPv6 hextets are valid (RFC 4291); exhaustive coverage lives in the v3 spec (#4367).
      context 'with a zero-padded IPv6 segment' do
        let(:destination) { '2001:0db8::1' }

        it { is_expected.to be true }
      end

      # A zero-padded embedded octet carries the same decimal/octal ambiguity as a bare IPv4 address.
      context 'with an IPv4-mapped IPv6 address' do
        context 'with a plain embedded octet' do
          let(:destination) { '::ffff:10.0.0.1' }

          it { is_expected.to be true }
        end

        context 'with a zero-padded embedded octet' do
          let(:destination) { '::ffff:010.0.0.1' }

          it { is_expected.to be false }
        end
      end

      context 'with a valid IPv6 range' do
        let(:destination) { '2001:db8::1-2001:db8::ff' }

        it { is_expected.to be true }
      end

      context 'with an inverted IPv6 range' do
        let(:destination) { '2001:db8::ff-2001:db8::1' }

        it { is_expected.to be false }
      end
    end
  end
end
