require 'spec_helper'

module VCAP::CloudController
  describe SharedDomain, type: :model do
    subject { described_class.make name: 'test.example.com' }

    it { is_expected.to have_timestamp_columns }

    describe 'Serialization' do
      it { is_expected.to export_attributes :name }
      it { is_expected.to import_attributes :name }
    end

    describe '#as_summary_json' do
      it 'returns a hash containing the guid and name' do
        expect(subject.as_summary_json).to eq(
                                             guid: subject.guid,
                                             name: 'test.example.com')
      end
    end

    describe '#validate' do
      include_examples 'domain validation'

      context 'when the name is foo.com and bar.foo.com is a shared domain' do
        before do
          SharedDomain.make name: 'bar.foo.com'
          subject.name = 'foo.com'
        end

        it { is_expected.to be_valid }
      end

      it 'allows shared foo.com when private bar.foo.com exists' do
        PrivateDomain.make name: 'bar.foo.com'
        expect { SharedDomain.make name: 'foo.com' }.to_not raise_error
      end

      it 'allows shared foo.com when shared bar.foo.com exists' do
        SharedDomain.make name: 'bar.foo.com'
        expect { SharedDomain.make name: 'foo.com' }.to_not raise_error
      end

      it 'allows shared bar.foo.com a when shared baz.bar.foo.com and foo.com exist' do
        SharedDomain.make name: 'baz.bar.foo.com'
        SharedDomain.make name: 'foo.com'
        expect { SharedDomain.make name: 'bar.foo.com' }.to_not raise_error
      end

      it 'allows shared bar.foo.com a when private baz.bar.foo.com and shared foo.com exist' do
        PrivateDomain.make name: 'baz.bar.foo.com'
        SharedDomain.make name: 'foo.com'
        expect { SharedDomain.make name: 'bar.foo.com' }.to_not raise_error
      end

      it 'denies shared bar.foo.com when private foo.com exists' do
        PrivateDomain.make name: 'foo.com'
        expect { SharedDomain.make name: 'bar.foo.com' }.to raise_error(Sequel::ValidationFailed, /overlapping_domain/)
      end
    end

    describe '#destroy' do
      it 'destroys the routes' do
        route = Route.make(domain: subject)

        expect do
          subject.destroy
        end.to change { Route.where(id: route.id).count }.by(-1)
      end
    end

    describe 'addable_to_organization!' do
      it 'does not raise error' do
        expect { subject.addable_to_organization!(Organization.new) }.to_not raise_error
      end
    end
  end
end
