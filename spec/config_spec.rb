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

      it "adds default stack file path" do
        config = Config.from_file(File.join(fixture_path, "config/minimal_config.yml"))
        config[:stacks_file].should == File.join(Config.config_dir, "stacks.yml")
      end
    end

    describe ".configure" do
      before do
        @test_config = {
            packages: {},
            droplets: {},
            cc_partition: "ng",
            bulk_api: {},
        }
      end

      it "sets up the db encryption key" do
        Config.configure(@test_config.merge(db_encryption_key: "123-456"))
        expect(Config.db_encryption_key).to eq("123-456")
      end

      it "sets up the account capacity" do
        Config.configure(@test_config.merge(admin_account_capacity: {memory: 64*1024}))
        expect(VCAP::CloudController::AccountCapacity.admin[:memory]).to eq(64*1024)

        VCAP::CloudController::AccountCapacity.admin[:memory] = AccountCapacity::ADMIN_MEM
      end

      it "sets up the resource pool instance" do
        Config.configure(@test_config.merge(resource_pool: {minimum_size: 9001}))
        expect(VCAP::CloudController::ResourcePool.instance.minimum_size).to eq(9001)
      end

      it "sets up the app package" do
        VCAP::CloudController::AppPackage.should_receive(:configure).with(@test_config)
        Config.configure(@test_config)
      end

      it "sets up the app manager" do
        Config.configure(@test_config)
        Config.configure_message_bus(message_bus)
        expect(VCAP::CloudController::AppManager.config).to eq(@test_config)
        expect(VCAP::CloudController::AppManager.message_bus).to eq(message_bus)

        expect(VCAP::CloudController::AppManager.stager_pool.config).to eq(@test_config)
        expect(VCAP::CloudController::AppManager.stager_pool.message_bus).to eq(message_bus)
      end

      it "sets the stagings controller" do
        VCAP::CloudController::StagingsController.should_receive(:configure).with(@test_config)
        Config.configure(@test_config)
      end

      it "sets the dea client" do
        Config.configure(@test_config)
        Config.configure_message_bus(message_bus)
        expect(VCAP::CloudController::DeaClient.config).to eq(@test_config)
        expect(VCAP::CloudController::DeaClient.message_bus).to eq(message_bus)

        message_bus.should_receive(:subscribe).at_least(:once)
        VCAP::CloudController::DeaClient.dea_pool.register_subscriptions
      end

      it "sets the legacy bulk" do
        bulk_config = {bulk_api: {auth_user: "user", auth_password: "password"}}
        Config.configure(@test_config.merge(bulk_config))
        Config.configure_message_bus(message_bus)
        expect(VCAP::CloudController::LegacyBulk.config[:auth_user]).to eq("user")
        expect(VCAP::CloudController::LegacyBulk.config[:auth_password]).to eq("password")
        expect(VCAP::CloudController::LegacyBulk.message_bus).to eq(message_bus)
      end

      it "sets up the quota definition" do
        VCAP::CloudController::Models::QuotaDefinition.should_receive(:configure).with(@test_config)
        Config.configure(@test_config)
      end

      it "sets up the stack" do
        config = @test_config.merge(stacks_file: "path/to/stacks/file")
        VCAP::CloudController::Models::Stack.should_receive(:configure).with("path/to/stacks/file")
        Config.configure(config)
      end

      it "sets up the service plan" do
        config = @test_config.merge(trial_db: "no quota")
        VCAP::CloudController::Models::ServicePlan.should_receive(:configure).with("no quota")
        Config.configure(config)
      end

      it "sets up the service plan" do
        config = @test_config.merge(trial_db: "no quota")
        VCAP::CloudController::Models::ServicePlan.should_receive(:configure).with("no quota")
        Config.configure(config)
      end
    end
  end
end
