require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Domain do
    it { is_expected.to have_timestamp_columns }

    it 'cannot create top level domains' do
      expect { Domain.make name: 'com' }.to raise_error(Sequel::ValidationFailed, /name.*alphanumeric characters and hyphens/)
    end

    it "can't be created if foo would become parent" do
      PrivateDomain.make name: 'bar.foo.com'
      expect { PrivateDomain.make name: 'foo.com' }.to raise_error(Sequel::ValidationFailed, /name overlapping_domain/)
    end

    describe 'Associations' do
      context 'routes' do
        let(:space) { Space.make }
        it { is_expected.to have_associated :routes,
             test_instance: SharedDomain.make,
             associated_instance: ->(domain) { Route.make(space: space, domain: domain) }
        }
      end

      context 'shared_organizations' do
        let(:org) { Organization.make }

        it 'associates with shared organizations' do
          domain = Domain.make(owning_organization_id: Organization.make.id)
          domain.add_shared_organization(org)
          expect(domain.shared_organizations).to include(org)
        end

        context 'when the domain is a shared domain' do
          it 'fails validation' do
            domain = Domain.make(owning_organization_id: nil)
            expect { domain.add_shared_organization(org) }.to raise_error(Sequel::HookFailed)
            expect(domain.shared_organizations).to_not include(org)
          end
        end

        context 'when the domain is owned by the organization' do
          it 'fails validation' do
            domain = Domain.make(owning_organization_id: org.id)
            expect { domain.add_shared_organization(org) }.to raise_error(Sequel::HookFailed)
            expect(domain.shared_organizations).to_not include(org)
          end
        end
      end

      context 'owning_organization' do
        let(:org) { Organization.make }
        it do
          is_expected.to have_associated :owning_organization,
            test_instance: Domain.make(owning_organization: org),
            associated_instance: ->(domain) { org }
        end
      end

      context 'changing owning_organization' do
        context 'shared domains' do
          it 'prevents converting a shared domain into a private domain' do
            shared = SharedDomain.make
            expect { shared.owning_organization = Organization.make }.to raise_error(CloudController::Errors::ApiError, /the owning organization cannot be changed/)
          end

          it 'succeeds when setting the org to the same thing' do
            shared = SharedDomain.make
            expect { shared.owning_organization = nil }.to_not raise_error
          end
        end

        context 'private domains' do
          it 'prevents converting a private domain into a shared domain' do
            private_domain = PrivateDomain.make
            expect { private_domain.owning_organization = nil }.to raise_error(CloudController::Errors::ApiError, /the owning organization cannot be changed/)
          end

          it 'prevents changing orgs on a private domain' do
            private_domain = PrivateDomain.make
            expect { private_domain.owning_organization = Organization.make }.to raise_error(CloudController::Errors::ApiError, /the owning organization cannot be changed/)
          end

          it 'succeeds when setting the org to the same thing' do
            org = Organization.make
            private_domain = PrivateDomain.make(owning_organization: org)
            expect { private_domain.owning_organization = org }.to_not raise_error
          end
        end
      end
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :name, :owning_organization_guid, :shared_organizations }
      it { is_expected.to import_attributes :name, :owning_organization_guid }
    end

    describe 'Validations' do
      it { is_expected.to validate_presence :name }
      it { is_expected.to validate_uniqueness :name }
    end

    describe '#spaces_sti_eager_load (eager loading)' do
      before { SharedDomain.dataset.destroy }

      it 'is able to eager load spaces' do
        domain = PrivateDomain.make
        org = domain.owning_organization

        space1 = Space.make(organization: org)
        space2 = Space.make(organization: org)

        expect {
          @eager_loaded_domain = Domain.eager(:spaces_sti_eager_load).where(id: domain.id).all.first
        }.to have_queried_db_times(/spaces/i, 1)

        expect {
          @eager_loaded_spaces = @eager_loaded_domain.spaces.to_a
        }.to have_queried_db_times(//, 0)

        expect(@eager_loaded_domain).to eql(domain)
        expect(@eager_loaded_spaces).to match_array([space1, space2])
        expect(@eager_loaded_spaces).to eql(org.spaces)
      end

      it 'has correct spaces for each domain' do
        domain1 = PrivateDomain.make
        domain2 = PrivateDomain.make

        org1 = domain1.owning_organization
        org2 = domain2.owning_organization

        space1 = Space.make(organization: org1)
        space2 = Space.make(organization: org2)

        expect {
          @eager_loaded_domains = Domain.eager(:spaces_sti_eager_load).where(id: [domain1.id, domain2.id]).order_by(:id).all
        }.to have_queried_db_times(/domains/i, 1)

        expect {
          expect(@eager_loaded_domains[0].spaces).to eql([space1])
          expect(@eager_loaded_domains[1].spaces).to eql([space2])
        }.to have_queried_db_times(//, 0)
      end

      it 'passes in dataset to be loaded to eager_block option' do
        domain = PrivateDomain.make
        org = domain.owning_organization

        space1 = Space.make(organization: org)
        Space.make(organization: org)

        eager_block = proc { |ds| ds.where(id: space1.id) }

        expect {
          @eager_loaded_domain = Domain.eager(spaces_sti_eager_load: eager_block).where(id: domain.id).all.first
        }.to have_queried_db_times(/domains/i, 1)

        expect(@eager_loaded_domain.spaces).to eql([space1])
      end

      it 'allow nested eager_load' do
        domain = PrivateDomain.make
        org = domain.owning_organization
        Space.make(organization: org)

        expect {
          @eager_loaded_domain = Domain.eager(spaces_sti_eager_load: :organization).where(id: domain.id).all.first
        }.to have_queried_db_times(/domains/i, 1)

        expect {
          expect(@eager_loaded_domain.spaces[0].organization).to eql(org)
        }.to have_queried_db_times(//, 0)
      end

      it 'copes with SharedDomain since they also are subclasses of Domain' do
        domain = SharedDomain.make

        expect {
          @eager_loaded_domain = Domain.eager(:spaces_sti_eager_load).where(id: domain.id).all.first
        }.to have_queried_db_times(/spaces/i, 1)
      end
    end

    describe '#name_overlaps?' do
      context 'when a domain exists that exactly matches the current name' do
        context 'when the organization is the same' do
          let(:organization) { Organization.make }

          it 'is false' do
            Domain.make(name: 'blah.blah.com', owning_organization: organization).save
            expect(Domain.new(name: 'blah.blah.com', owning_organization: organization).name_overlaps?).to be false
          end
        end

        context 'when the organization is different' do
          it 'is true' do
            Domain.make(name: 'blah.blah.com', owning_organization: Organization.make).save
            expect(Domain.new(name: 'blah.blah.com', owning_organization: Organization.make).name_overlaps?).to be true
          end
        end

        context 'but the first domain has no organization' do
          it 'is false' do
            Domain.make(name: 'blah.blah.com', owning_organization: nil).save
            expect(Domain.new(name: 'blah.blah.com', owning_organization: Organization.make).name_overlaps?).to be false
          end
        end
      end

      context 'when no other private domain matches the name' do
        it 'is false' do
          Domain.make(name: 'blah.example.com', owning_organization: Organization.make).save
          expect(Domain.new(name: 'blah.blah.com', owning_organization: Organization.make).name_overlaps?).to be false
        end
      end
    end
  end
end
