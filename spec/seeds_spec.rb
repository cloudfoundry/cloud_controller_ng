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
      let(:config) do
        {
          quota_definitions: {
            "free" => {
              non_basic_services_allowed: false,
              total_routes: 10,
              total_services: 10,
              memory_limit: 1024,
            },

            "paid" => {
              non_basic_services_allowed: true,
              total_routes: 1000,
              total_services: 20,
              memory_limit: 1_024_000,
            },
          }}
      end
      context "when there are no quota definitions" do
        before do
          QuotaDefinition.dataset.delete
        end

        it "makes them all" do
          expect {
            Seeds.create_seed_quota_definitions(config)
          }.to change{QuotaDefinition.count}.from(0).to(2)

          free_quota = QuotaDefinition[name: "free"]
          expect(free_quota.non_basic_services_allowed).to eq(false)
          expect(free_quota.total_routes).to eq(10)
          expect(free_quota.total_services).to eq(10)
          expect(free_quota.memory_limit).to eq(1024)

          paid_quota = QuotaDefinition[name: "paid"]
          expect(paid_quota.non_basic_services_allowed).to eq(true)
          expect(paid_quota.total_routes).to eq(1000)
          expect(paid_quota.total_services).to eq(20)
          expect(paid_quota.memory_limit).to eq(1_024_000)
        end
      end

      context "when all the quota definitions exist already" do
        before do
          QuotaDefinition.dataset.delete
          Seeds.create_seed_quota_definitions(config)
        end

        context "when the existing records exactly match the config" do
          it "does not create duplicates" do
            expect {
              Seeds.create_seed_quota_definitions(config)
            }.not_to change{QuotaDefinition.count}

            free_quota = QuotaDefinition[name: "free"]
            expect(free_quota.non_basic_services_allowed).to eq(false)
            expect(free_quota.total_routes).to eq(10)
            expect(free_quota.total_services).to eq(10)
            expect(free_quota.memory_limit).to eq(1024)

            paid_quota = QuotaDefinition[name: "paid"]
            expect(paid_quota.non_basic_services_allowed).to eq(true)
            expect(paid_quota.total_routes).to eq(1000)
            expect(paid_quota.total_services).to eq(20)
            expect(paid_quota.memory_limit).to eq(1_024_000)
          end
        end

        context "when there are records with names that match but other fields that do not match" do
          it "warns" do
            mock_logger = double
            Steno.stub(:logger).and_return(mock_logger)
            config[:quota_definitions]["free"][:total_routes] = 2

            mock_logger.should_receive(:warn).with("seeds.quota-collision", hash_including(name: "free"))

            Seeds.create_seed_quota_definitions(config)
          end
        end
      end
    end

    describe ".create_seed_organizations" do
      context "when system domain organization is missing in the configuration" do
        it "does not create an organization" do
          config_without_org = config.clone
          config_without_org.delete(:system_domain_organization)

          expect {
            Seeds.create_seed_organizations(config_without_org)
          }.not_to change { Organization.count }
        end
      end

      context "when system domain organization exists in the configuration" do
        context "when 'paid' quota definition is missing" do
          before { QuotaDefinition.dataset.delete }

          it "raises error" do
            expect do
              Seeds.create_seed_organizations(config)
            end.to raise_error(ArgumentError, /missing 'paid' quota definition in config file/i)
          end
        end

        context "when 'paid' quota definition exists" do
          before do
            QuotaDefinition.dataset.delete
            QuotaDefinition.make(:name => "paid")
            Organization.dataset.delete
          end

          it "creates the system organization when the organization does not already exist" do
            expect {
              Seeds.create_seed_organizations(config)
            }.to change { Organization.count }.from(0).to(1)

            org = Organization.first
            expect(org.quota_definition.name).to eq("paid")
            expect(org.name).to eq("the-system_domain-org-name")
          end

          it "warns when the system organization exists and has a different quota" do
            Seeds.create_seed_organizations(config)
            org = Organization.find(name: "the-system_domain-org-name")
            QuotaDefinition.make(name: "runaway")
            org.quota_definition = QuotaDefinition.find(name: "runaway")
            org.save(validate: false) # See tracker story #61090364

            mock_logger = double
            Steno.stub(:logger).and_return(mock_logger)

            mock_logger.should_receive(:warn).with("seeds.system-domain-organization.collision", existing_quota_name: "runaway")

            Seeds.create_seed_organizations(config)
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
