require 'cloud_controller/domain_decorator'

module CloudController
  RSpec.describe DomainDecorator do
    describe '#intermediate_domains' do
      it 'returns an empty array if the name is nil' do
        expect(DomainDecorator.new(nil).intermediate_domains).to be_empty
      end

      it 'returns an empty array if the name not a valid domain' do
        expect(DomainDecorator.new('invalid_domain').intermediate_domains).to be_empty
      end

      it 'returns all of the intermediate domains except the tld' do
        expect(DomainDecorator.new('long.named.example.com').intermediate_domains.map(&:name)).
          to match_array(['long.named.example.com', 'named.example.com', 'example.com'])
      end

      context 'when the domain includes a newline character' do
        it 'returns an empty array if the name not a valid domain' do
          expect(DomainDecorator.new("bosh-lite.com\nbosh-lite.com").intermediate_domains).to be_empty
        end
      end
    end

    describe '#has_sub_domain?' do
      it 'returns false when domains are completely different' do
        expect(DomainDecorator.new('bosh-lite.com').has_sub_domain?(test_domains: ['apps.com'])).
          to be_falsey
      end

      it 'returns false when domains are completely different, but end in the same name lexically' do
        expect(DomainDecorator.new('bosh-lite.com').has_sub_domain?(test_domains: ['lite.com'])).
          to be_falsey
      end

      it 'returns true when test_domain and domain are equal' do
        expect(DomainDecorator.new('bosh-lite.com').has_sub_domain?(test_domains: ['bosh-lite.com'])).
          to be_truthy
      end

      it 'returns true when test_domain is a subdomain of domain' do
        expect(DomainDecorator.new('bosh-lite.com').has_sub_domain?(test_domains: ['apps.bosh-lite.com'])).
          to be_truthy
      end

      it 'returns true when any test_domain is a subdomain of domain' do
        expect(DomainDecorator.new('bosh-lite.com').has_sub_domain?(test_domains: ['bosh-lite.com', 'apps.bosh-lite.com', 'example.com'])).
          to be_truthy
      end

      it 'returns false when domains contain system domain and another domain' do
        expect(DomainDecorator.new('bosh-lite.com').has_sub_domain?(test_domains: ['apps.com', 'bosh-lite.com'])).
          to be_falsey
      end
    end

    describe '#is_sub_domain_of?' do
      it 'returns true if the domain is a subdomain of the provided parent domain' do
        expect(DomainDecorator.new('foo.bosh-lite.com').is_sub_domain_of?(parent_domain_name: 'bosh-lite.com')).
          to be true
      end

      it 'returns false if the domain is the provided parent domain' do
        expect(DomainDecorator.new('bosh-lite.com').is_sub_domain_of?(parent_domain_name: 'bosh-lite.com')).
          to be false
      end

      it 'returns false if the domain is NOT a subdomain of the provided parent domain' do
        expect(DomainDecorator.new('foo.bosh-lite.com').is_sub_domain_of?(parent_domain_name: 'example.com')).
          to be false
      end
    end

    describe '#parent_domain' do
      it 'returns the domain without the hostname' do
        expect(DomainDecorator.new('api.bosh-lite.com').parent_domain).to eq DomainDecorator.new('bosh-lite.com')
      end

      context 'when it is a TLD' do
        it 'returns itself' do
          expect(DomainDecorator.new('com').parent_domain).to eq DomainDecorator.new('com')
        end
      end
    end

    describe '#hostname' do
      it 'returns the domain\'s hostname' do
        expect(DomainDecorator.new('api.bosh-lite.com').hostname).to eq 'api'
      end

      context 'when it is a TLD' do
        it 'returns nil' do
          expect(DomainDecorator.new('com').hostname).to be_nil
        end
      end
    end

    describe '#valid_format?' do
      it 'is true if the domain conforms to some regex' do
        expect(DomainDecorator.new('foo.bar.baz').valid_format?).to be true
        expect(DomainDecorator.new('bar.baz').valid_format?).to be true
        expect(DomainDecorator.new('bar-bar.baz').valid_format?).to be true
        expect(DomainDecorator.new('a.b').valid_format?).to be true
      end

      it 'is false otherwise' do
        expect(DomainDecorator.new("#{'a' * 64}.baz").valid_format?).to be false
        expect(DomainDecorator.new("foo.#{'a' * 64}").valid_format?).to be false
        expect(DomainDecorator.new('-bar.baz').valid_format?).to be false
        expect(DomainDecorator.new('bar-.baz').valid_format?).to be false
        expect(DomainDecorator.new('bar.-baz').valid_format?).to be false
        expect(DomainDecorator.new('bar.baz-').valid_format?).to be false
        expect(DomainDecorator.new('baz').valid_format?).to be false
      end
    end
  end
end
