require 'spec_helper'

RSpec.describe MaxPrivateDomainsPolicy do
  let(:quota_definition) { double(:quota_definition, total_private_domains: 4) }
  let(:private_domain_counter) { double(:private_domain_counter, count: 0) }

  subject { MaxPrivateDomainsPolicy.new(quota_definition, private_domain_counter) }

  describe '#allow_more_private_domains?' do
    it 'is false when exceeding the total allowed private_domains' do
      result = subject.allow_more_private_domains?(5)
      expect(result).to eq(false)
    end

    it 'is true when equivalent to the total allowed private domains' do
      result = subject.allow_more_private_domains?(4)
      expect(result).to eq(true)
    end

    it 'is true when not exceeding the total allowed private domains' do
      result = subject.allow_more_private_domains?(1)
      expect(result).to eq(true)
    end

    context 'when an unlimited amount of private domains are available' do
      let(:quota_definition) { double(:quota_definition, total_private_domains: -1) }

      it 'is always true' do
        result = subject.allow_more_private_domains?(100_000_000)
        expect(result).to eq(true)
      end
    end
  end
end
