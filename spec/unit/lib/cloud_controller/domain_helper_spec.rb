require 'cloud_controller/domain_helper'

module CloudController
  RSpec.describe DomainHelper do
    describe '.intermediate_domains' do
      # TODO: (pego): not sure this is really what we want or if we want this to raise an error
      it 'returns an empty array if the name is nil' do
        expect(DomainHelper.intermediate_domains(nil)).to be_empty
      end

      # TODO: (pego): not sure this is really what we want or if we want this to raise an error
      it 'returns an empty array if the name not a valid domain' do
        expect(DomainHelper.intermediate_domains('invalid_domain')).to be_empty
      end

      it 'returns all of the intermediate domains except the tld' do
        expect(DomainHelper.intermediate_domains('long.named.example.com')).
          to match_array(['long.named.example.com', 'named.example.com', 'example.com'])
      end
    end

    describe '.is_sub_domain?' do
      it 'returns false when test_domain and domain are equal' do
        expect(DomainHelper.is_sub_domain?(domain: 'bosh-lite.com', test_domains: ['bosh-lite.com'])).
          to be_falsey
      end

      it 'returns false when domains are completely different' do
        expect(DomainHelper.is_sub_domain?(domain: 'bosh-lite.com', test_domains: ['apps.com'])).
          to be_falsey
      end

      it 'returns false when domains are completely different, but end in the same name lexically' do
        expect(DomainHelper.is_sub_domain?(domain: 'bosh-lite.com', test_domains: ['lite.com'])).
          to be_falsey
      end

      it 'returns true when test_domain is a subdomain of domain' do
        expect(DomainHelper.is_sub_domain?(domain: 'bosh-lite.com', test_domains: ['apps.bosh-lite.com'])).
          to be_truthy
      end

      it 'returns true when any test_domain is a subdomain of domain' do
        expect(DomainHelper.is_sub_domain?(domain: 'bosh-lite.com', test_domains: ['bosh-lite.com', 'apps.bosh-lite.com', 'example.com'])).
          to be_truthy
      end

      it 'returns false when domains contain system domain and another domain' do
        expect(DomainHelper.is_sub_domain?(domain: 'bosh-lite.com', test_domains: ['apps.com', 'bosh-lite.com'])).
          to be_falsey
      end
    end
  end
end
