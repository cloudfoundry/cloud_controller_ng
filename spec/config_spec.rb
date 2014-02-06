require "spec_helper"

module VCAP::CloudController
  describe Config do
    let(:message_bus) { Config.message_bus }

    describe ".from_file" do
      it "raises if the file does not exist" do
        expect {
          Config.from_file("nonexistent.yml")
        }.to raise_error(Errno::ENOENT, /No such file or directory - nonexistent.yml/)
      end
    end

    describe "default" do
      it "sets default stacks_file" do
        config = Config.from_file(File.join(fixture_path, "config/minimal_config.yml"))
        expect(config[:stacks_file]).to eq(File.join(Config.config_dir, "stacks.yml"))
      end

      it "sets default maximum_app_disk_in_mb" do
        config = Config.from_file(File.join(fixture_path, "config/minimal_config.yml"))
        expect(config[:maximum_app_disk_in_mb]).to eq(2048)
      end

      it "sets default directories" do
        config = Config.from_file(File.join(fixture_path, "config/minimal_config.yml"))
        expect(config[:directories]).to eq({})
      end
    end

    describe ".configure_components" do
      before do
        @test_config = {
          packages: {},
          droplets: {},
          cc_partition: "ng",
          bulk_api: {},
        }
      end

      it "sets up the db encryption key" do
        Config.configure_components(@test_config.merge(db_encryption_key: "123-456"))
        expect(Encryptor.db_encryption_key).to eq("123-456")
      end

      it "sets up the account capacity" do
        Config.configure_components(@test_config.merge(admin_account_capacity: {memory: 64*1024}))
        expect(AccountCapacity.admin[:memory]).to eq(64*1024)

        AccountCapacity.admin[:memory] = AccountCapacity::ADMIN_MEM
      end

      it "sets up the resource pool instance" do
        Config.configure_components(@test_config.merge(resource_pool: {minimum_size: 9001}))
        expect(ResourcePool.instance.minimum_size).to eq(9001)
      end

      it "sets up the app manager" do
        expect(AppObserver).to receive(:configure).with(
          @test_config,
          message_bus,
          instance_of(DeaPool),
          instance_of(StagerPool))

        Config.configure_components(@test_config)
        Config.configure_components_depending_on_message_bus(message_bus)
      end

      it "sets the dea client" do
        Config.configure_components(@test_config)
        Config.configure_components_depending_on_message_bus(message_bus)
        expect(DeaClient.config).to eq(@test_config)
        expect(DeaClient.message_bus).to eq(message_bus)

        message_bus.should_receive(:subscribe).at_least(:once)
        DeaClient.dea_pool.register_subscriptions
      end

      it "sets the legacy bulk" do
        bulk_config = {bulk_api: {auth_user: "user", auth_password: "password"}}
        Config.configure_components(@test_config.merge(bulk_config))
        Config.configure_components_depending_on_message_bus(message_bus)
        expect(LegacyBulk.config[:auth_user]).to eq("user")
        expect(LegacyBulk.config[:auth_password]).to eq("password")
        expect(LegacyBulk.message_bus).to eq(message_bus)
      end

      it "sets up the quota definition" do
        QuotaDefinition.should_receive(:configure).with(@test_config)
        Config.configure_components(@test_config)
      end

      it "sets up the stack" do
        config = @test_config.merge(stacks_file: "path/to/stacks/file")
        Stack.should_receive(:configure).with("path/to/stacks/file")
        Config.configure_components(config)
      end

      it "sets up the service plan" do
        config = @test_config.merge(trial_db: "no quota")
        ServicePlan.should_receive(:configure).with("no quota")
        Config.configure_components(config)
      end

      it "sets up the service plan" do
        config = @test_config.merge(trial_db: "no quota")
        ServicePlan.should_receive(:configure).with("no quota")
        Config.configure_components(config)
      end

      it "sets up app with whether custom buildpacks are enabled" do
        config = @test_config.merge(disable_custom_buildpacks: true)

        expect {
          Config.configure_components(config)
        }.to change {
          App.custom_buildpacks_enabled?
        }.to(false)

        config = @test_config.merge(disable_custom_buildpacks: false)

        expect {
          Config.configure_components(config)
        }.to change {
          App.custom_buildpacks_enabled?
        }.to(true)
      end
    end
  end
end
