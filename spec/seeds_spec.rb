require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::Seeds do
    describe ".create_seed_stacks" do
      it "populates stacks" do
        Stack.should_receive(:populate)
        Seeds.create_seed_stacks(config)
      end
    end

    describe ".create_seed_quota_definitions" do
      it "creates quota definitions" do
        QuotaDefinition.should_receive(:update_or_create).with(:name => "free")
        QuotaDefinition.should_receive(:update_or_create).with(:name => "paid")
        QuotaDefinition.should_receive(:update_or_create).with(:name => "trial")

        Seeds.create_seed_quota_definitions(config)
      end
    end

    describe ".create_seed_organizations" do
      context "when 'paid' quota definition is missing" do
        it "raises error" do
          QuotaDefinition.should_receive(:find).with(:name => "paid")

          expect do
            Seeds.create_seed_organizations(config)
          end.to raise_error(ArgumentError,
            /missing 'paid' quota definition in config file/i)
        end
      end

      context "when 'paid' quota definition exists" do
        before do
          unless QuotaDefinition.find(:name => "paid")
            QuotaDefinition.make(:name => "paid")
          end
        end

        context "when system domain organization is missing in the configuration" do
          it "does not raise error" do
            config_without_org = config.clone
            config_without_org.delete(:system_domain_organization)

            expect do
              Seeds.create_seed_organizations(config_without_org)
            end.to_not raise_error
          end
        end

        context "when system domain organization exists in the configuration" do
          it "creates the system organization" do
            Seeds.create_seed_organizations(config).should_not be_nil
          end
        end
      end
    end

    describe ".create_seed_domains" do
      before do
        unless QuotaDefinition.find(:name => "paid")
          QuotaDefinition.make(:name => "paid")
        end
        @system_org = Seeds.create_seed_organizations(config)
      end

      it "creates seed domains" do
        Domain.should_receive(:populate_from_config).with(config, @system_org)

        Seeds.create_seed_domains(config, @system_org)
      end
    end
 
    describe "create_seed_domains" do
      let(:existing_org) { Organization.make }

      it "should add app domains to existing organizations" do
        @system_org = Seeds.create_seed_organizations(config)
        Seeds.create_seed_domains(config, @system_org) 

        existing_org.reload
        existing_org.domains.size.should eq(2)

        config[:app_domains] << "foo.com"
        Seeds.create_seed_domains(config,@system_org)

        existing_org.reload
        existing_org.domains.size.should eq(3)
      end
    end
  end
end
