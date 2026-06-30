require 'spec_helper'

module VCAP::CloudController
  RSpec.describe PrivateDomain, type: :model do
    let(:private_domain) { create(:private_domain, name: 'test.example.com') }
    let(:reserved) { nil }

    before do
      TestConfig.override(system_domain: 'customer-app-domain1.com', reserved_private_domains: reserved)
    end

    it { is_expected.to have_timestamp_columns }

    describe 'Associations' do
      it 'has associated spaces' do
        private_domain = create(:private_domain)
        space = create(:space, organization: private_domain.owning_organization)
        expect(private_domain.spaces).to include(space.reload)
      end
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :name, :owning_organization_guid }
      it { is_expected.to import_attributes :name, :owning_organization_guid }
    end

    describe 'Validations' do
      it { is_expected.to validate_presence :owning_organization }

      describe 'domain' do
        subject { private_domain }
        include_examples 'domain validation'
      end

      it 'denies private uaa.customer-app-domain1.com when customer-app-domain1.com is the system domain' do
        expect { create(:private_domain, name: 'uaa.customer-app-domain1.com') }.to raise_error(Sequel::ValidationFailed, /is already reserved by the system/)
      end

      it 'allows private bar.foo.com when foo.com has the same owner' do
        private_domain = create(:private_domain, name: 'foo.com')
        expect { create(:private_domain, name: 'bar.foo.com', owning_organization_id: private_domain.owning_organization_id) }.not_to raise_error
      end

      it 'allows private foo.com a when bar.foo.com has the same owner' do
        private_domain = create(:private_domain, name: 'bar.foo.com')
        expect { create(:private_domain, name: 'foo.com', owning_organization_id: private_domain.owning_organization_id) }.not_to raise_error
      end

      it 'denies private foo.com when another org has bar.foo.com' do
        create(:private_domain, name: 'bar.foo.com')
        expect { create(:private_domain, name: 'foo.com') }.to raise_error(Sequel::ValidationFailed, /is already reserved by another domain/)
      end

      it 'denies private foo.com when there is a shared bar.foo.com' do
        create(:shared_domain, name: 'bar.foo.com')
        expect { create(:private_domain, name: 'foo.com') }.to raise_error(Sequel::ValidationFailed, /is already reserved by another domain/)
      end

      it 'denies private foo.com when there is a shared foo.com' do
        create(:shared_domain, name: 'foo.com')
        expect { create(:private_domain, name: 'foo.com') }.to raise_error(Sequel::ValidationFailed, /name unique/)
      end

      it 'allows private bar.foo.com a when private baz.bar.foo.com has the same owner and shared foo.com exist' do
        private_domain = create(:private_domain, name: 'baz.bar.foo.com')
        create(:shared_domain, name: 'foo.com')
        expect { create(:private_domain, name: 'bar.foo.com', owning_organization_id: private_domain.owning_organization_id) }.not_to raise_error
      end

      it 'denies private bar.foo.com a when private baz.bar.foo.com has a different owner and shared foo.com exist' do
        create(:private_domain, name: 'baz.bar.foo.com')
        create(:shared_domain, name: 'foo.com')
        error_msg = %(The domain name "bar.foo.com" cannot be created because "baz.bar.foo.com" is already reserved by another domain)
        expect { create(:private_domain, name: 'bar.foo.com') }.to raise_error(Sequel::ValidationFailed, error_msg)
      end

      it 'denies private bar.foo.com a when shared baz.bar.foo.com and foo.com exist' do
        create(:shared_domain, name: 'baz.bar.foo.com')
        create(:shared_domain, name: 'foo.com')
        error_msg = %(The domain name "bar.foo.com" cannot be created because "baz.bar.foo.com" is already reserved by another domain)
        expect { create(:private_domain, name: 'bar.foo.com') }.to raise_error(Sequel::ValidationFailed, error_msg)
      end

      context 'with reserved private domains' do
        let(:reserved) { File.join(Paths::FIXTURES, 'config/reserved_private_domains.dat') }

        it 'handles normal reserved domain names' do
          expect { create(:private_domain, name: 'com.ac') }.to raise_error(Sequel::ValidationFailed, /reserved/)
          expect { create(:private_domain, name: 'a.com.ac') }.not_to raise_error
          expect { create(:private_domain, name: 'scom.ac') }.not_to raise_error
        end

        it 'handles wildcard reserved domain names' do
          expect { create(:private_domain, name: 'b.wild.card') }.to raise_error(Sequel::ValidationFailed, /reserved/)
          expect { create(:private_domain, name: 'a.b.wild.card') }.not_to raise_error
        end

        it 'handles exception reserved domain names' do
          expect { create(:private_domain, name: 'a.wild.card') }.not_to raise_error
        end

        context 'with a missing file' do
          let(:reserved) { nil }

          it 'raises an error' do
            expect { PrivateDomain.configure('bogus') }.to raise_error(Errno::ENOENT)
          end
        end
      end

      describe 'total allowed private domains' do
        let(:organization) { create(:organization) }
        let(:org_quota) { organization.quota_definition }

        subject(:domain) { PrivateDomain.new(name: 'foo.com', owning_organization: organization) }

        context 'on create' do
          context 'when not exceeding total private domains' do
            before do
              org_quota.total_private_domains = 10
              org_quota.save
            end

            it 'does not have an error on organization' do
              subject.valid?
              expect(subject.errors.on(:organization)).to be_nil
            end
          end

          context 'when exceeding total private domains' do
            before do
              org_quota.total_private_domains = 0
              org_quota.save
            end

            it 'has the error on organization' do
              subject.valid?
              expect(subject.errors.on(:organization)).to include :total_private_domains_exceeded
            end
          end
        end

        context 'on update' do
          it 'does not validate the total private domains limit if already existing' do
            subject.save

            expect(subject).to be_valid

            org_quota.total_private_domains = 0
            org_quota.save

            expect(subject).to be_valid
          end
        end
      end
    end

    describe '#as_summary_json' do
      it 'returns a hash containing the guid, name, and owning organization guid' do
        expect(private_domain.as_summary_json).to eq(
          guid: private_domain.guid,
          name: 'test.example.com',
          owning_organization_guid: private_domain.owning_organization.guid
        )
      end
    end

    describe '#in_suspended_or_deleting_org?' do
      let(:org) { create(:organization) }
      let(:private_domain) { PrivateDomain.new(owning_organization: org) }

      context 'when in a suspended organization' do
        before { allow(org).to receive(:suspended_or_deleting?).and_return(true) }

        it 'is true' do
          expect(private_domain).to be_in_suspended_or_deleting_org
        end
      end

      context 'when in an un-suspended organization' do
        before { allow(org).to receive(:suspended_or_deleting?).and_return(false) }

        it 'is false' do
          expect(private_domain).not_to be_in_suspended_or_deleting_org
        end
      end
    end

    describe '#destroy' do
      let(:space) { create(:space, organization: private_domain.owning_organization) }

      before do
        TestConfig.override(kubernetes: {})
      end

      it 'destroys the routes' do
        route = create(:route, domain: private_domain, space: space)

        expect do
          private_domain.destroy
        end.to change { Route.where(id: route.id).count }.by(-1)
      end
    end

    describe 'addable_to_organization!' do
      it 'raises error when the domain belongs to a different org' do
        expect do
          private_domain.addable_to_organization!(Organization.new)
        end.to raise_error(Domain::UnauthorizedAccessToPrivateDomain)
      end

      it 'does not raise error when the domain belongs to a different org' do
        expect do
          private_domain.addable_to_organization!(private_domain.owning_organization)
        end.not_to raise_error
      end
    end

    describe 'usable_by_organization?' do
      it 'returns true when its the owner' do
        expect(private_domain.usable_by_organization?(private_domain.owning_organization)).to be true
      end

      context 'when not the owner' do
        it 'returns true when allowed to share the domain' do
          org = create(:organization)
          private_domain.add_shared_organization(org)
          expect(private_domain.usable_by_organization?(org)).to be true
        end

        it 'returns false if not allowed to share the domain' do
          expect(private_domain.usable_by_organization?(Organization.new)).to be false
        end
      end
    end
  end
end
