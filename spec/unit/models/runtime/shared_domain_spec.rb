require 'spec_helper'

module VCAP::CloudController
  describe SharedDomain, type: :model do
    subject { described_class.make name: 'test.example.com', router_group_guid: 'my-router-group-guid', router_group_type: 'tcp' }

    it { is_expected.to have_timestamp_columns }

    describe 'Serialization' do
      it { is_expected.to export_attributes :name, :router_group_guid, :router_group_type }
      it { is_expected.to import_attributes :name, :router_group_guid }
    end

    describe '#as_summary_json' do
      it 'returns a hash containing the guid and name' do
        expect(subject.as_summary_json).to eq(
          guid: subject.guid,
          name: 'test.example.com',
          router_group_guid: 'my-router-group-guid',
          router_group_type: 'tcp')
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

      it 'denies shared foo.com when private foo.com exists' do
        PrivateDomain.make name: 'foo.com'
        expect { SharedDomain.make name: 'foo.com' }.to raise_error(Sequel::ValidationFailed, /name unique/)
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

    describe '#tcp?' do
      context 'when shared domain is a tcp domain' do
        let(:shared_domain) { SharedDomain.make(name: 'tcp.com', router_group_guid: '123') }

        it 'returns true' do
          expect(shared_domain.tcp?).to be_truthy
        end
      end

      context 'when shared domain is not a tcp domain' do
        let(:shared_domain) { SharedDomain.make(name: 'tcp.com') }

        it 'returns false' do
          expect(shared_domain.tcp?).to eq(false)
        end
      end
    end

    describe 'addable_to_organization!' do
      it 'does not raise error' do
        expect { subject.addable_to_organization!(Organization.new) }.to_not raise_error
      end
    end
  end
end
