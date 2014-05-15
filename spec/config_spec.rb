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

    describe ".merge_defaults" do
      context "when no config values are provided" do
        let (:config) { Config.from_file(File.join(fixture_path, "config/minimal_config.yml")) }
        it "sets default stacks_file" do
          expect(config[:stacks_file]).to eq(File.join(Config.config_dir, "stacks.yml"))
        end

        it "sets default maximum_app_disk_in_mb" do
          expect(config[:maximum_app_disk_in_mb]).to eq(2048)
        end

        it "sets default directories" do
          expect(config[:directories]).to eq({})
        end

        it "enables writing billing events" do
          expect(config[:billing_event_writing_enabled]).to be_true
        end

        it "sets a default request_timeout_in_seconds value" do
          expect(config[:request_timeout_in_seconds]).to eq(300)
        end

        it "sets a default value for skip_cert_verify" do
          expect(config[:skip_cert_verify]).to eq false
        end

        it "sets a default value for app_bits_upload_grace_period_in_seconds" do
          expect(config[:app_bits_upload_grace_period_in_seconds]).to eq(0)
        end
      end

      context "when config values are provided" do
        context "and the values are valid" do
          let (:config) { Config.from_file(File.join(fixture_path, "config/default_overriding_config.yml")) }

          it "preserves the stacks_file value from the file" do
            expect(config[:stacks_file]).to eq("/tmp/foo")
          end

          it "preserves the maximum_app_disk_in_mb value from the file" do
            expect(config[:maximum_app_disk_in_mb]).to eq(3)
          end

          it "preserves the directories value from the file" do
            expect(config[:directories]).to eq({ some: "value" })
          end

          it "preserves the external_protocol value from the file" do
            expect(config[:external_protocol]).to eq("http")
          end

          it "preserves the billing_event_writing_enabled value from the file" do
            expect(config[:billing_event_writing_enabled]).to be_false
          end

          it "preserves the request_timeout_in_seconds value from the file" do
            expect(config[:request_timeout_in_seconds]).to eq(600)
          end

          it "preserves the value of skip_cert_verify from the file" do
            expect(config[:skip_cert_verify]).to eq true
          end

          it "preserves the value for app_bits_upload_grace_period_in_seconds" do
            expect(config[:app_bits_upload_grace_period_in_seconds]).to eq(600)
          end
        end

        context "and the values are invalid" do
          let(:tmpdir) { Dir.mktmpdir }
          let (:config_from_file) { Config.from_file(File.join(tmpdir, "incorrect_overridden_config.yml")) }

          before do
            config_hash = YAML.load_file(File.join(fixture_path, "config/minimal_config.yml"))
            config_hash["app_bits_upload_grace_period_in_seconds"] = -2345

            File.open(File.join(tmpdir, "incorrect_overridden_config.yml"), "w") do |f|
              YAML.dump(config_hash, f)
            end
          end

          after do
            FileUtils.rm_r(tmpdir)
          end

          it "reset the negative value of app_bits_upload_grace_period_in_seconds to 0" do
            expect(config_from_file[:app_bits_upload_grace_period_in_seconds]).to eq(0)
          end
        end
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
          instance_of(StagerPool),
          instance_of(DiegoClient))

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

      it "starts the staging task completion handler" do
        StagingCompletionHandler.any_instance.should_receive(:subscribe!)

        Config.configure_components(@test_config)
        Config.configure_components_depending_on_message_bus(message_bus)
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

      it "sets up app with whether custom buildpacks are enabled" do
        config = @test_config.merge(disable_custom_buildpacks: true)

        expect {
          Config.configure_components(config)
        }.to change {
          VCAP::CloudController::Config.config[:disable_custom_buildpacks]
        }.to(true)

        config = @test_config.merge(disable_custom_buildpacks: false)

        expect {
          Config.configure_components(config)
        }.to change {
          VCAP::CloudController::Config.config[:disable_custom_buildpacks]
        }.to(false)
      end
    end
  end
end
