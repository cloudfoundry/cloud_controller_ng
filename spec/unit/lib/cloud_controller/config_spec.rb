require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Config do
    let(:test_config_hash) {
      {
        admin_account_capacity: { memory: 64 * 1024 },
        packages: {
          fog_connection: {},
          fog_aws_storage_options: {
            encryption: 'AES256'
          },
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
          minimum_size: 9001,
          maximum_size: 0,
          fog_connection: {},
          resource_directory_key: 'resource_key',
        },
        bulk_api: {},
        external_domain: 'host',
        external_port: 1234,
        staging: {
          auth: {
            user: 'user',
            password: 'password',
          },
        },
        bits_service: { enabled: false },
        reserved_private_domains: File.join(Paths::FIXTURES, 'config/reserved_private_domains.dat'),
        diego: {},
        stacks_file: 'path/to/stacks/file',
        db_encryption_key: '123-456',
        install_buildpacks: [
          {
            name: 'some-buildpack',
          }
        ]
      }
    }

    describe '.load_from_file' do
      it 'raises if the file does not exist' do
        expect {
          Config.load_from_file('nonexistent.yml')
        }.to raise_error(Errno::ENOENT, /No such file or directory @ rb_sysopen - nonexistent.yml/)
      end

      context 'merges default values' do
        context 'when no config values are provided' do
          let(:config) do
            config_path = File.join(Paths::FIXTURES, 'config/minimal_config.yml')
            Config.load_from_file(config_path).config_hash
          end

          it 'sets the default isolation segment name' do
            expect(config[:shared_isolation_segment_name]).to eq('shared')
          end

          it 'sets default stacks_file' do
            expect(config[:stacks_file]).to eq(File.join(Paths::CONFIG, 'stacks.yml'))
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

          it 'sets a default value for min staging memory' do
            expect(config[:staging][:minimum_staging_memory_mb]).to eq(1024)
          end

          it 'sets a default value for min staging file descriptor limit' do
            expect(config[:staging][:minimum_staging_file_descriptor_limit]).to eq(16384)
          end

          it 'sets a default value for broker_timeout_seconds' do
            expect(config[:broker_client_timeout_seconds]).to eq(60)
          end

          it 'sets a default value for broker_client_default_async_poll_interval_seconds' do
            expect(config[:broker_client_default_async_poll_interval_seconds]).to eq(60)
          end

          it ' sets a default value for num_of_valid_packages_per_app_to_store' do
            expect(config[:packages][:max_valid_packages_stored]).to eq(5)
          end

          it ' sets a default value for num_of_staged_droplets_per_app_to_store' do
            expect(config[:droplets][:max_staged_droplets_stored]).to eq(5)
          end

          it 'sets a default value for the bits service' do
            expect(config[:bits_service]).to eq({ enabled: false })
          end
        end

        context 'when config values are provided' do
          context 'and the values are valid' do
            let(:config) do
              config_path = File.join(Paths::FIXTURES, 'config/default_overriding_config.yml')
              Config.load_from_file(config_path).config_hash
            end

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
              let(:config_load_from_file) do
                config_path = File.join(tmpdir, 'overridden_with_urlencoded_values.yml')
                Config.load_from_file(config_path).config_hash
              end

              before do
                config_hash = YAML.load_file(File.join(Paths::FIXTURES, 'config/minimal_config.yml'))
                config_hash['staging']['auth']['user'] = 'f%40t%3A%25a'
                config_hash['staging']['auth']['password'] = 'm%40%2Fn!'

                File.open(File.join(tmpdir, 'overridden_with_urlencoded_values.yml'), 'w') do |f|
                  YAML.dump(config_hash, f)
                end
              end

              it 'preserves the url-encoded values' do
                config_load_from_file[:staging][:auth][:user] = 'f%40t%3A%25a'
                config_load_from_file[:staging][:auth][:password] = 'm%40%2Fn!'
              end
            end
          end

          context 'and the password contains double quotes' do
            let(:tmpdir) { Dir.mktmpdir }
            let(:config_load_from_file) do
              config_path = File.join(tmpdir, 'incorrect_overridden_config.yml')
              Config.load_from_file(config_path).config_hash
            end

            before do
              config_hash = YAML.load_file(File.join(Paths::FIXTURES, 'config/minimal_config.yml'))
              config_hash['staging']['auth']['password'] = 'pass"wor"d'

              File.open(File.join(tmpdir, 'incorrect_overridden_config.yml'), 'w') do |f|
                YAML.dump(config_hash, f)
              end
            end

            after do
              FileUtils.rm_r(tmpdir)
            end

            it 'URL-encodes staging password as neccesary' do
              expect(config_load_from_file[:staging][:auth][:password]).to eq('pass%22wor%22d')
            end
          end

          context 'and the values are invalid' do
            let(:tmpdir) { Dir.mktmpdir }
            let(:config_load_from_file) do
              config_path = File.join(tmpdir, 'incorrect_overridden_config.yml')
              Config.load_from_file(config_path).config_hash
            end

            before do
              config_hash = YAML.load_file(File.join(Paths::FIXTURES, 'config/minimal_config.yml'))
              config_hash['app_bits_upload_grace_period_in_seconds'] = -2345
              config_hash['staging']['auth']['user'] = 'f@t:%a'
              config_hash['staging']['auth']['password'] = 'm@/n!'
              config_hash['diego']['pid_limit'] = -5

              File.open(File.join(tmpdir, 'incorrect_overridden_config.yml'), 'w') do |f|
                YAML.dump(config_hash, f)
              end
            end

            after do
              FileUtils.rm_r(tmpdir)
            end

            it 'reset the negative value of app_bits_upload_grace_period_in_seconds to 0' do
              expect(config_load_from_file[:app_bits_upload_grace_period_in_seconds]).to eq(0)
            end

            it 'sets a negative "pid_limit" to 0' do
              expect(config_load_from_file[:diego][:pid_limit]).to eq(0)
            end

            it 'URL-encodes staging auth as necessary' do
              expect(config_load_from_file[:staging][:auth][:user]).to eq('f%40t%3A%25a')
              expect(config_load_from_file[:staging][:auth][:password]).to eq('m%40%2Fn!')
            end
          end
        end
      end
    end

    describe '#configure_components' do
      let(:dependency_locator) { CloudController::DependencyLocator.instance }

      let(:test_config_hash) {
        {
          admin_account_capacity: { memory: 64 * 1024 },
          packages: {
            fog_connection: {},
            fog_aws_storage_options: {
              encryption: 'AES256'
            },
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
            minimum_size: 9001,
            maximum_size: 0,
            fog_connection: {},
            resource_directory_key: 'resource_key',
          },
          bulk_api: {},
          external_host: 'host',
          external_port: 1234,
          staging: {
            auth: {
              user: 'user',
              password: 'password',
            },
          },
          bits_service: { enabled: false },
          reserved_private_domains: File.join(Paths::FIXTURES, 'config/reserved_private_domains.dat'),
          diego: {},
          stacks_file: 'path/to/stacks/file',
          db_encryption_key: '123-456'
        }
      }

      let(:config_instance) do
        Config.new(test_config_hash)
      end

      before do
        allow(Stack).to receive(:configure)
      end

      after do
        AccountCapacity.admin[:memory] = AccountCapacity::ADMIN_MEM
      end

      it 'sets up the db encryption key' do
        config_instance.configure_components
        expect(Encryptor.db_encryption_key).to eq('123-456')
      end

      it 'sets up the resource pool instance' do
        config_instance.configure_components
        expect(ResourcePool.instance.minimum_size).to eq(9001)
      end

      it 'sets up the app manager' do
        expect(AppObserver).to receive(:configure).with(instance_of(Stagers), instance_of(Runners))

        config_instance.configure_components
      end

      it 'sets up the quota definition' do
        expect(QuotaDefinition).to receive(:configure).with(config_instance)
        config_instance.configure_components
      end

      it 'sets up the stack' do
        expect(Stack).to receive(:configure).with('path/to/stacks/file')
        config_instance.configure_components
      end

      it 'sets up app with whether custom buildpacks are enabled' do
        config = Config.new(test_config_hash.merge(disable_custom_buildpacks: true))
        expect(config.get(:disable_custom_buildpacks)).to be true

        config = Config.new(test_config_hash.merge(disable_custom_buildpacks: false))
        expect(config.get(:disable_custom_buildpacks)).to be false
      end

      context 'when newrelic is disabled' do
        let(:config_instance) do
          Config.new(test_config_hash.merge(newrelic_enabled: false))
        end

        before do
          GC::Profiler.disable
        end

        it 'does not enable GC profiling' do
          config_instance.configure_components
          expect(GC::Profiler.enabled?).to eq(false)
        end
      end

      context 'when newrelic is enabled' do
        let(:config_instance) do
          Config.new(test_config_hash.merge(newrelic_enabled: true))
        end

        before do
          GC::Profiler.disable
        end

        it 'enables GC profiling' do
          config_instance.configure_components
          expect(GC::Profiler.enabled?).to eq(true)
        end
      end

      it 'sets up the reserved private domain' do
        expect(PrivateDomain).to receive(:configure).with(test_config_hash[:reserved_private_domains])
        config_instance.configure_components
      end
    end

    describe '#get' do
      let(:config_instance) do
        Config.new(test_config_hash)
      end

      it 'returns the value at the given key' do
        expect(config_instance.get(:external_domain)).to eq 'host'
      end

      it 'returns an array at the given key' do
        expect(config_instance.get(:install_buildpacks)).to eq([{ name: 'some-buildpack' }])
      end

      it 'returns a hash for nested properties' do
        expect(config_instance.get(:packages)).to eq({
                                                       fog_connection: {},
                                                       fog_aws_storage_options: {
                                                         encryption: 'AES256'
                                                       },
                                                       app_package_directory_key: 'app_key',
                                                     })
        expect(config_instance.get(:packages, :fog_aws_storage_options)).to eq(encryption: 'AES256')
      end

      it 'raises an exception when given an invalid key' do
        expect {
          config_instance.get(:blub_blub)
        }.to raise_error Config::InvalidConfigPath, /"blub_blub" is not a valid config key/
      end

      it 'raises when you dig into a leaf property' do
        expect {
          config_instance.get(:external_domain, :pantaloons)
        }.to raise_error Config::InvalidConfigPath, /"external_domain.pantaloons" is not a valid config key/
      end

      it 'raises when you dig into hashes' do
        expect {
          config_instance.get(:packages, :fog_aws_storage_options, :encryption)
        }.to raise_error Config::InvalidConfigPath, /"packages.fog_aws_storage_options.encryption" is not a valid config key/
      end

      it 'raises when given a path with an invalid key' do
        expect {
          config_instance.get(:packages, :ham_sandwich)
        }.to raise_error Config::InvalidConfigPath, /"packages.ham_sandwich" is not a valid config key/
      end

      it 'raises when you dig into arrays' do
        expect {
          config_instance.get(:install_buildpacks, :name)
        }.to raise_error Config::InvalidConfigPath, /"install_buildpacks.name" is not a valid config key/
      end
    end

    describe '#set' do
      let(:config_instance) do
        Config.new(test_config_hash)
      end

      it 'saves the value at the key in the config' do
        config_instance.set(:external_host, 'foobar.example.com')
        expect(config_instance.get(:external_host)).to eq 'foobar.example.com'
      end
    end
  end
end
