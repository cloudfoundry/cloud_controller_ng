module VCAP::CloudController
  RSpec.shared_examples_for 'domain validation' do
    context 'when the name is not present' do
      before { subject.name = nil }

      it { is_expected.not_to be_valid }

      it 'fails to validate' do
        subject.validate
        expect(subject.errors[:name]).to include(:presence)
      end
    end

    context "when there's another domain with the same name" do
      it 'fails to validate' do
        other_domain = create(described_class.name.demodulize.underscore.to_sym)
        other_domain.name = subject.name
        expect(other_domain).not_to be_valid
        expect(other_domain.errors[:name]).to include(:unique)
      end
    end

    describe 'name format validation' do
      it 'accepts a two level domain' do
        subject.name = 'a.com'
        expect(subject).to be_valid
      end

      it 'accepts a three level domain' do
        subject.name = 'a.b.com'
        expect(subject).to be_valid
      end

      it 'accepts a four level domain' do
        subject.name = 'a.b.c.com'
        expect(subject).to be_valid
      end

      it 'accepts a domain with a 2 char top level domain' do
        subject.name = 'b.c.au'
        expect(subject).to be_valid
      end

      it 'does not allow a one level domain' do
        subject.name = 'com'
        expect(subject).not_to be_valid
      end

      it 'does not allow a domain without a host' do
        subject.name = '.com'
        expect(subject).not_to be_valid
      end

      it 'does not allow a domain with a trailing dot' do
        subject.name = 'a.com.'
        expect(subject).not_to be_valid
      end

      it 'does not allow a domain with a leading dot' do
        subject.name = '.b.c.com'
        expect(subject).not_to be_valid
      end

      it 'allows a domain with a single char top level domain' do
        subject.name = 'b.c.d'
        expect(subject).to be_valid
      end

      it 'allows a domain with a 6 char top level domain' do
        subject.name = 'b.c.abcefg'
        expect(subject).to be_valid
      end

      it 'does not allow a domain with > 253 characters' do
        subdomain = 'a' * 63
        subject.name = "#{subdomain}.#{subdomain}.#{subdomain}.#{'a' * 61}"
        expect(subject).to be_valid

        subject.name = "#{subdomain}.#{subdomain}.#{subdomain}.#{'a' * 61}x"
        expect(subject).not_to be_valid
      end

      it 'does not allow a subdomain with > 63 characters' do
        subdomain = 'a' * 63
        subject.name = "#{subdomain}.#{subdomain}"
        expect(subject).to be_valid

        subdomain = 'a' * 63
        subject.name = "#{subdomain}x.#{subdomain}"
        expect(subject).not_to be_valid
      end

      it 'permits whitespace but strip it out' do
        subject.name = ' foo.com '
        expect(subject).to be_valid
        expect(subject.name).to eq('foo.com')
      end
    end

    context 'route matching' do
      it 'denies creating a domain when a matching route exists' do
        shared_domain = create(:shared_domain, name: 'foo.com')
        create(:route, host: 'bar', domain_guid: shared_domain.guid)
        subject.name = 'bar.foo.com'
        expect(subject).not_to be_valid
      end

      it 'denies creating a domain that is a subdomain of an existing route' do
        shared_domain = create(:shared_domain, name: 'foo.com')
        create(:route, host: 'bar', domain_guid: shared_domain.guid)
        subject.name = 'baz.bar.foo.com'
        expect(subject).not_to be_valid
      end

      it 'denies creating a domain that is a distant subdomain of an existing route' do
        shared_domain = create(:shared_domain, name: 'foo.com')
        create(:route, host: 'bar', domain_guid: shared_domain.guid)
        subject.name = 'corge.quux.baz.bar.foo.com'
        expect(subject).not_to be_valid
      end
    end

    context 'domain overlapping' do
      context 'when the domain exists in a different casing' do
        before do
          create(:private_domain, name: 'foo.com')
          subject.name = 'FoO.CoM'
        end

        it { is_expected.not_to be_valid }
      end

      context 'when the name is bar.foo.com and another org has foo.com' do
        before do
          create(:private_domain, name: 'foo.com')
          subject.name = 'bar.foo.com'
        end

        it { is_expected.not_to be_valid }
      end

      context 'when the name is baz.bar.foo.com and another org has bar.foo.com' do
        before do
          create(:private_domain, name: 'bar.foo.com')
          subject.name = 'baz.bar.foo.com'
        end

        it { is_expected.not_to be_valid }
      end

      context 'when the name is baz.bar.foo.com and another org has bar.foo.com and foo.com is shared' do
        before do
          create(:shared_domain, name: 'foo.com')
          create(:private_domain, name: 'bar.foo.com')
          subject.name = 'baz.bar.foo.com'
        end

        it { is_expected.not_to be_valid }
      end

      context 'when the name is bar.foo.com and foo.com is a shared domain' do
        before do
          create(:shared_domain, name: 'foo.com')
          subject.name = 'bar.foo.com'
        end

        it { is_expected.to be_valid }
      end

      context 'when the name is baz.bar.foo.com and bar.foo.com is a shared domain' do
        before do
          create(:shared_domain, name: 'bar.foo.com')
          subject.name = 'baz.bar.foo.com'
        end

        it { is_expected.to be_valid }
      end
    end
  end
end
