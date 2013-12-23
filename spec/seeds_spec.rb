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
            "small" => {
              non_basic_services_allowed: false,
              total_routes: 10,
              total_services: 10,
              memory_limit: 1024,
            },

            "default" => {
              non_basic_services_allowed: true,
              total_routes: 1000,
              total_services: 20,
              memory_limit: 1_024_000,
            },
          },
          :default_quota_definition => "default",
        }
      end
      context "when there are no quota definitions" do
        before do
          QuotaDefinition.dataset.delete
        end

        it "makes them all" do
          expect {
            Seeds.create_seed_quota_definitions(config)
          }.to change{QuotaDefinition.count}.from(0).to(2)

          small_quota = QuotaDefinition[name: "small"]
          expect(small_quota.non_basic_services_allowed).to eq(false)
          expect(small_quota.total_routes).to eq(10)
          expect(small_quota.total_services).to eq(10)
          expect(small_quota.memory_limit).to eq(1024)

          default_quota = QuotaDefinition[name: "default"]
          expect(default_quota.non_basic_services_allowed).to eq(true)
          expect(default_quota.total_routes).to eq(1000)
          expect(default_quota.total_services).to eq(20)
          expect(default_quota.memory_limit).to eq(1_024_000)
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

            small_quota = QuotaDefinition[name: "small"]
            expect(small_quota.non_basic_services_allowed).to eq(false)
            expect(small_quota.total_routes).to eq(10)
            expect(small_quota.total_services).to eq(10)
            expect(small_quota.memory_limit).to eq(1024)

            default_quota = QuotaDefinition[name: "default"]
            expect(default_quota.non_basic_services_allowed).to eq(true)
            expect(default_quota.total_routes).to eq(1000)
            expect(default_quota.total_services).to eq(20)
            expect(default_quota.memory_limit).to eq(1_024_000)
          end
        end

        context "when there are records with names that match but other fields that do not match" do
          it "warns" do
            mock_logger = double
            Steno.stub(:logger).and_return(mock_logger)
            config[:quota_definitions]["small"][:total_routes] = 2

            mock_logger.should_receive(:warn).with("seeds.quota-collision", hash_including(name: "small"))

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
        context "when default quota definition is missing in configuraition" do
          before { QuotaDefinition.dataset.delete }

          it "raises error" do
            expect do
              Seeds.create_seed_organizations(config)
            end.to raise_error(ArgumentError, /missing default quota definition in config file/i)
          end
        end

        context "when default quota definition exists" do
          before do
            QuotaDefinition.dataset.delete
            QuotaDefinition.make(:name => "default")
            Organization.dataset.delete
          end

          it "creates the system organization when the organization does not already exist" do
            expect {
              Seeds.create_seed_organizations(config)
            }.to change { Organization.count }.from(0).to(1)

            org = Organization.first
            expect(org.quota_definition.name).to eq("default")
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
      let(:config) do
        {
          :app_domains => [
            "app.example.com"
          ],
          :system_domain => "system.example.com",
          :system_domain_organization => "the-system-org",
          :quota_definitions => {
            "default" => {
              non_basic_services_allowed: true,
              total_routes: 1000,
              total_services: 20,
              memory_limit: 1_024_000,
            },
          },
          :default_quota_definition => "default"
        }
      end

      before do
        Domain.dataset.delete
        QuotaDefinition.dataset.delete
        QuotaDefinition.make(:name => "default")
        Seeds.create_seed_organizations(config)
      end

      context "when the app domains do not include the system domain" do
        it "makes shared domains for each of the config's app domains" do
          Seeds.create_seed_domains(config, Organization.find(name: "the-system-org"))
          expect(Domain.shared_domains.map(&:name)).to eq(["app.example.com"])
        end

        it "raises if the system org is not specified" do
          expect { Seeds.create_seed_domains(config, nil) }.to raise_error
        end

        it "creates the system domain if the system domain does not exist" do
          system_org = Organization.find(name: "the-system-org")
          Seeds.create_seed_domains(config, system_org)

          system_domain = Domain.find(name: config[:system_domain])
          expect(system_domain.owning_organization).to eq(system_org)
        end

        it "warns if the system domain exists but has different attributes from the seed" do
          mock_logger = double(:info => nil)
          Steno.stub(:logger).and_return(mock_logger)

          mock_logger.should_receive(:warn).with("seeds.system-domain.collision", instance_of(Hash))

          PrivateDomain.create(
            name: config[:system_domain],
            owning_organization: Organization.make
          )
          system_org = Organization.find(name: "the-system-org")
          Seeds.create_seed_domains(config, system_org)
        end
      end

      context "when the app domains include the system domain" do
        before do
          config[:app_domains] << config[:system_domain]
        end

        it "makes shared domains for each of the config's app domains, including the system domain" do
          Seeds.create_seed_domains(config, Organization.find(name: "the-system-org"))
          expect(Domain.shared_domains.map(&:name)).to eq(config[:app_domains])
        end
      end
    end
  end
end
