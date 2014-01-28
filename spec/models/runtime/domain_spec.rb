require "spec_helper"

module VCAP::CloudController
  describe Domain do
    describe "#spaces_sti_eager_load (eager loading)" do
      before { SharedDomain.dataset.delete }

      it "is able to eager load spaces" do
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
        expect(@eager_loaded_spaces).to eql([space1, space2])
        expect(@eager_loaded_spaces).to eql(org.spaces)
      end

      it "has correct spaces for each domain" do
        domain1 = PrivateDomain.make
        domain2 = PrivateDomain.make

        org1 = domain1.owning_organization
        org2 = domain2.owning_organization

        space1 = Space.make(organization: org1)
        space2 = Space.make(organization: org2)

        expect {
          @eager_loaded_domains = Domain.eager(:spaces_sti_eager_load).where(id: [domain1.id, domain2.id]).limit(2).all
        }.to have_queried_db_times(/domains/i, 1)

        expect {
          expect(@eager_loaded_domains[0].spaces).to eql([space1])
          expect(@eager_loaded_domains[1].spaces).to eql([space2])
        }.to have_queried_db_times(//, 0)
      end

      it "passes in dataset to be loaded to eager_block option" do
        domain = PrivateDomain.make
        org = domain.owning_organization

        space1 = Space.make(organization: org)
        space2 = Space.make(organization: org)

        eager_block = proc { |ds| ds.where(id: space1.id) }

        expect {
          @eager_loaded_domain = Domain.eager(spaces_sti_eager_load: eager_block).where(id: domain.id).all.first
        }.to have_queried_db_times(/domains/i, 1)

        expect(@eager_loaded_domain.spaces).to eql([space1])
      end

      it "allow nested eager_load" do
        domain = PrivateDomain.make
        org = domain.owning_organization
        space1 = Space.make(organization: org)

        expect {
          @eager_loaded_domain = Domain.eager(spaces_sti_eager_load: :organization).where(id: domain.id).all.first
        }.to have_queried_db_times(/domains/i, 1)

        expect {
          expect(@eager_loaded_domain.spaces[0].organization).to eql(org)
        }.to have_queried_db_times(//, 0)
      end

      it "copes with SharedDomain since they also are subclasses of Domain" do
        domain = SharedDomain.make

        expect {
          @eager_loaded_domain = Domain.eager(:spaces_sti_eager_load).where(id: domain.id).all.first
        }.to have_queried_db_times(/spaces/i, 1)
      end
    end
  end
end
