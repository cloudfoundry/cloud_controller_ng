require 'spec_helper'

module VCAP::CloudController
  describe Config do
    let(:message_bus) { Config.message_bus }

    describe '.from_file' do
      it 'raises if the file does not exist' do
        expect {
          Config.from_file('nonexistent.yml')
        }.to raise_error(Errno::ENOENT, /No such file or directory @ rb_sysopen - nonexistent.yml/)
      end
    end

    describe '.merge_defaults' do
      context 'when no config values are provided' do
        let(:config) { Config.from_file(File.join(Paths::FIXTURES, 'config/minimal_config.yml')) }
        it 'sets default stacks_file' do
          expect(config[:stacks_file]).to eq(File.join(Config.config_dir, 'stacks.yml'))
        end

        it 'sets default maximum_app_disk_in_mb' do
          expect(config[:maximum_app_disk_in_mb]).to eq(2048)
        end

        it 'sets default directories' do
          expect(config[:directories]).to eq({})
        end

        it 'sets a default request_timeout_in_seconds value' do
          expect(config[:request_timeout_in_seconds]).to eq(900)
        end

        it 'sets a default value for skip_cert_verify' do
          expect(config[:skip_cert_verify]).to eq false
        end

        it 'sets a default value for app_bits_upload_grace_period_in_seconds' do
          expect(config[:app_bits_upload_grace_period_in_seconds]).to eq(0)
        end

        it 'sets a default value for database' do
          expect(config[:db][:database]).to eq(ENV['DB_CONNECTION_STRING'])
        end

        it 'sets a default value for allowed_cors_domains' do
          expect(config[:allowed_cors_domains]).to eq([])
        end

        it 'allows users to select the backend for their apps' do
          expect(config[:users_can_select_backend]).to eq(true)
        end

        it 'runs apps on the dea' do
          expect(config[:default_to_diego_backend]).to eq(false)
        end

        it 'sets a default value for min staging memory' do
          expect(config[:staging][:minimum_staging_memory_mb]).to eq(1024)
        end

        it 'sets a default value for min staging disk' do
          expect(config[:staging][:minimum_staging_disk_mb]).to eq(4096)
        end

        it 'sets a default value for min staging file descriptor limit' do
          expect(config[:staging][:minimum_staging_file_descriptor_limit]).to eq(16384)
        end

        it 'sets a default value for advertisement_timeout_in_seconds' do
          expect(config[:dea_advertisement_timeout_in_seconds]).to eq(10)
        end

        it 'sets a default value for placement_top_stager_percentage' do
          expect(config[:placement_top_stager_percentage]).to eq(10)
        end

        it 'sets a default value for broker_timeout_seconds' do
          expect(config[:broker_client_timeout_seconds]).to eq(60)
        end

        it 'sets a default value for broker_client_default_async_poll_interval_seconds' do
          expect(config[:broker_client_default_async_poll_interval_seconds]).to eq(60)
        end

        it 'does not set a default value for internal_service_hostname' do
          expect(config[:internal_service_hostname]).to be_nil
        end

        it ' sets a default value for num_of_valid_packages_per_app_to_store' do
          expect(config[:packages][:max_valid_packages_stored]).to eq(5)
        end

        it ' sets a default value for num_of_staged_droplets_per_app_to_store' do
          expect(config[:droplets][:max_staged_droplets_stored]).to eq(5)
        end
      end

      context 'when config values are provided' do
        context 'and the values are valid' do
          let(:config) { Config.from_file(File.join(Paths::FIXTURES, 'config/default_overriding_config.yml')) }

          it 'preserves cli info from the file' do
            expect(config[:info][:min_cli_version]).to eq('6.0.0')
            expect(config[:info][:min_recommended_cli_version]).to eq('6.9.0')
          end

          it 'preserves the stacks_file value from the file' do
            expect(config[:stacks_file]).to eq('/tmp/foo')
          end

          it 'preserves the default_app_disk_in_mb value from the file' do
            expect(config[:default_app_disk_in_mb]).to eq(512)
          end

          it 'preserves the maximum_app_disk_in_mb value from the file' do
            expect(config[:maximum_app_disk_in_mb]).to eq(3)
          end

          it 'preserves the directories value from the file' do
            expect(config[:directories]).to eq({ some: 'value' })
          end

          it 'preserves the external_protocol value from the file' do
            expect(config[:external_protocol]).to eq('http')
          end

          it 'preserves the request_timeout_in_seconds value from the file' do
            expect(config[:request_timeout_in_seconds]).to eq(600)
          end

          it 'preserves the value of skip_cert_verify from the file' do
            expect(config[:skip_cert_verify]).to eq true
          end

          it 'preserves the value for app_bits_upload_grace_period_in_seconds' do
            expect(config[:app_bits_upload_grace_period_in_seconds]).to eq(600)
          end

          it 'preserves the value of the staging auth user/password' do
            expect(config[:staging][:auth][:user]).to eq('user')
            expect(config[:staging][:auth][:password]).to eq('password')
          end

          it 'preserves the values of the minimum staging limits' do
            expect(config[:staging][:minimum_staging_memory_mb]).to eq(512)
            expect(config[:staging][:minimum_staging_disk_mb]).to eq(1024)
            expect(config[:staging][:minimum_staging_file_descriptor_limit]).to eq(2048)
          end

          it 'preserves the value of the allowed cross-origin domains' do
            expect(config[:allowed_cors_domains]).to eq(['http://andrea.corr', 'http://caroline.corr', 'http://jim.corr', 'http://sharon.corr'])
          end

          it 'preserves the backend selection configuration from the file' do
            expect(config[:users_can_select_backend]).to eq(false)
          end

          it 'runs apps on diego' do
            expect(config[:default_to_diego_backend]).to eq(true)
          end

          it 'preserves the enable allow ssh configuration from the file' do
            expect(config[:allow_app_ssh_access]).to eq(true)
          end

          it 'preserves the default_health_check_timeout value from the file' do
            expect(config[:default_health_check_timeout]).to eq(30)
          end

          it 'preserves the maximum_health_check_timeout value from the file' do
            expect(config[:maximum_health_check_timeout]).to eq(90)
          end

          it 'preserves the broker_client_timeout_seconds value from the file' do
            expect(config[:broker_client_timeout_seconds]).to eq(120)
          end

          it 'preserves the broker_client_default_async_poll_interval_seconds value from the file' do
            expect(config[:broker_client_default_async_poll_interval_seconds]).to eq(120)
          end

          it 'preserves the internal_service_hostname value from the file' do
            expect(config[:internal_service_hostname]).to eq('cloud_controller_ng.service.cf.internal')
          end

          it 'preserves the expiration values from the file' do
            expect(config[:packages][:max_valid_packages_stored]).to eq(10)
            expect(config[:droplets][:max_staged_droplets_stored]).to eq(10)
          end

          context 'when the staging auth is already url encoded' do
            let(:tmpdir) { Dir.mktmpdir }
            let(:config_from_file) { Config.from_file(File.join(tmpdir, 'overridden_with_urlencoded_values.yml')) }

            before do
              config_hash = YAML.load_file(File.join(Paths::FIXTURES, 'config/minimal_config.yml'))
              config_hash['staging']['auth']['user'] = 'f%40t%3A%25a'
              config_hash['staging']['auth']['password'] = 'm%40%2Fn!'

              File.open(File.join(tmpdir, 'overridden_with_urlencoded_values.yml'), 'w') do |f|
                YAML.dump(config_hash, f)
              end
            end

            it 'preserves the url-encoded values' do
              config_from_file[:staging][:auth][:user] = 'f%40t%3A%25a'
              config_from_file[:staging][:auth][:password] = 'm%40%2Fn!'
            end
          end
        end

        context 'and the values are invalid' do
          let(:tmpdir) { Dir.mktmpdir }
          let(:config_from_file) { Config.from_file(File.join(tmpdir, 'incorrect_overridden_config.yml')) }

          before do
            config_hash = YAML.load_file(File.join(Paths::FIXTURES, 'config/minimal_config.yml'))
            config_hash['app_bits_upload_grace_period_in_seconds'] = -2345
            config_hash['staging']['auth']['user'] = 'f@t:%a'
            config_hash['staging']['auth']['password'] = 'm@/n!'

            File.open(File.join(tmpdir, 'incorrect_overridden_config.yml'), 'w') do |f|
              YAML.dump(config_hash, f)
            end
          end

          after do
            FileUtils.rm_r(tmpdir)
          end

          it 'reset the negative value of app_bits_upload_grace_period_in_seconds to 0' do
            expect(config_from_file[:app_bits_upload_grace_period_in_seconds]).to eq(0)
          end

          it 'URL-encodes staging auth as neccesary' do
            expect(config_from_file[:staging][:auth][:user]).to eq('f%40t%3A%25a')
            expect(config_from_file[:staging][:auth][:password]).to eq('m%40%2Fn!')
          end
        end
      end
    end

    describe '.configure_components' do
      let(:dependency_locator) { CloudController::DependencyLocator.instance }

      before do
        @test_config = {
          packages: {
            fog_connection: {},
            app_package_directory_key: 'app_key',
          },
          droplets: {
            fog_connection: {},
            droplet_directory_key: 'droplet_key',
          },
          buildpacks: {
            fog_connection: {},
            buildpack_directory_key: 'bp_key',
          },
          resource_pool: {
            minimum_size: 0,
            maximum_size: 0,
            fog_connection: {},
            resource_directory_key: 'resource_key',
          },
          cc_partition: 'ng',
          bulk_api: {},
          external_host: 'host',
          external_port: 1234,
          staging: {
            auth: {
              user: 'user',
              password: 'password',
            },
          },
        }
      end

      it 'sets up the db encryption key' do
        Config.configure_components(@test_config.merge(db_encryption_key: '123-456'))
        expect(Encryptor.db_encryption_key).to eq('123-456')
      end

      it 'sets up the account capacity' do
        Config.configure_components(@test_config.merge(admin_account_capacity: { memory: 64 * 1024 }))
        expect(AccountCapacity.admin[:memory]).to eq(64 * 1024)

        AccountCapacity.admin[:memory] = AccountCapacity::ADMIN_MEM
      end

      it 'sets up the resource pool instance' do
        Config.configure_components(@test_config.merge(resource_pool: { minimum_size: 9001 }))
        expect(ResourcePool.instance.minimum_size).to eq(9001)
      end

      it 'creates the runners' do
        expect(VCAP::CloudController::Runners).to receive(:new).with(
          @test_config,
          message_bus,
          instance_of(Dea::Pool),
          instance_of(Dea::StagerPool))
        Config.configure_components(@test_config)
        Config.configure_components_depending_on_message_bus(message_bus)
      end

      it 'creates the stagers' do
        expect(VCAP::CloudController::Stagers).to receive(:new).with(
          @test_config,
          message_bus,
          instance_of(Dea::Pool),
          instance_of(Dea::StagerPool),
          instance_of(Runners))
        Config.configure_components(@test_config)
        Config.configure_components_depending_on_message_bus(message_bus)
      end

      it 'creates the dea stager pool' do
        expect(Dea::StagerPool).to receive(:new).and_call_original

        Config.configure_components(@test_config)
        Config.configure_components_depending_on_message_bus(message_bus)
      end

      it 'sets up the app manager' do
        expect(AppObserver).to receive(:configure).with(instance_of(VCAP::CloudController::Stagers), instance_of(VCAP::CloudController::Runners))

        Config.configure_components(@test_config)
        Config.configure_components_depending_on_message_bus(message_bus)
      end

      it 'sets the dea client' do
        Config.configure_components(@test_config)
        Config.configure_components_depending_on_message_bus(message_bus)
        expect(Dea::Client.config).to eq(@test_config)
        expect(Dea::Client.message_bus).to eq(message_bus)

        expect(message_bus).to receive(:subscribe).at_least(:once)
        Dea::Client.dea_pool.register_subscriptions
      end

      it 'sets the legacy bulk' do
        bulk_config = { bulk_api: { auth_user: 'user', auth_password: 'password' } }
        Config.configure_components(@test_config.merge(bulk_config))
        Config.configure_components_depending_on_message_bus(message_bus)
        expect(LegacyBulk.config[:auth_user]).to eq('user')
        expect(LegacyBulk.config[:auth_password]).to eq('password')
        expect(LegacyBulk.message_bus).to eq(message_bus)
      end

      it 'sets up the quota definition' do
        expect(QuotaDefinition).to receive(:configure).with(@test_config)
        Config.configure_components(@test_config)
      end

      it 'sets up the stack' do
        config = @test_config.merge(stacks_file: 'path/to/stacks/file')
        expect(Stack).to receive(:configure).with('path/to/stacks/file')
        Config.configure_components(config)
      end

      it 'sets up app with whether custom buildpacks are enabled' do
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

      context 'when newrelic is disabled' do
        let(:config) do
          @test_config.merge(newrelic_enabled: false)
        end

        before do
          GC::Profiler.disable
          Config.instance_eval('@initialized = false')
        end

        it 'does not enable GC profiling' do
          Config.configure_components(config)
          expect(GC::Profiler.enabled?).to eq(false)
        end
      end

      context 'when newrelic is enabled' do
        let(:config) do
          @test_config.merge(newrelic_enabled: true)
        end

        before do
          GC::Profiler.disable
          Config.instance_eval('@initialized = false')
        end

        it 'enables GC profiling' do
          Config.configure_components(config)
          expect(GC::Profiler.enabled?).to eq(true)
        end
      end

      it 'creates the nsync client' do
        expect(Diego::NsyncClient).to receive(:new).with(@test_config).and_call_original

        Config.configure_components(@test_config)
        expect(dependency_locator.nsync_client).to be_an_instance_of(VCAP::CloudController::Diego::NsyncClient)
      end

      it 'creates the stager client' do
        expect(Diego::StagerClient).to receive(:new).with(@test_config).and_call_original

        Config.configure_components(@test_config)
        expect(dependency_locator.stager_client).to be_an_instance_of(VCAP::CloudController::Diego::StagerClient)
      end
    end
  end
end
