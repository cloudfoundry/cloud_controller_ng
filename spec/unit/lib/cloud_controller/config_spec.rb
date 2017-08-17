require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Config do
    let(:test_config_hash) {
      {
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

    describe '#load_from_file' do
      it 'raises if the file does not exist' do
        expect {
          Config.load_from_file('nonexistent.yml', context: :worker)
        }.to raise_error(Errno::ENOENT, /No such file or directory @ rb_sysopen - nonexistent.yml/)
      end

      context 'merges default values' do
        after do
          cc_config_file.unlink
        end

        context 'when no config values are provided' do
          let(:null_overrides) do
            [
              'bits_service',
              'stacks_file',
              'directories',
              'request_timeout_in_seconds',
              'skip_cert_verify',
              'app_bits_upload_grace_period_in_seconds',
              'allowed_cors_domains',
              'users_can_select_backend',
              'broker_client_timeout_seconds',
              'broker_client_default_async_poll_interval_seconds',
            ]
          end

          let(:cc_config_file) do
            config = YAML.load_file('config/cloud_controller.yml')
            null_overrides.each { |override| config.delete(override) }
            config['staging'].delete('minimum_staging_memory_mb')
            config['staging'].delete('minimum_staging_file_descriptor_limit')
            config['db'].delete('database')
            config['packages'].delete('max_valid_packages_stored')
            config['droplets'].delete('max_staged_droplets_stored')

            file = Tempfile.new('cc_config.yml')
            file.write(YAML.dump(config))
            file.close
            file
          end

          let(:config) do
            Config.load_from_file(cc_config_file, context: :worker).config_hash
          end

          it 'does not set a default for database_encryption_keys' do
            expect(config[:database_encryption_keys]).to be_nil
          end

          it 'sets default stacks_file' do
            expect(config[:stacks_file]).to eq(File.join(Paths::CONFIG, 'stacks.yml'))
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
            let(:cc_config_file) do
              config = YAML.load_file('config/cloud_controller.yml')
              config['stacks_file'] = '/tmp/foo'
              config['users_can_select_backend'] = false
              config['maximum_app_disk_in_mb'] = 3072
              config['broker_client_default_async_poll_interval_seconds'] = 42
              config['broker_client_timeout_seconds'] = 70
              config['database_encryption_keys'] = {
                  keys: {
                      'foo' => 'bar',
                      'current' => 'yomama',
                      'head' => 'banging'
                  },
                  current_key_label: 'foo'
              }

              file = Tempfile.new('cc_config.yml')
              file.write(YAML.dump(config))
              file.close
              file
            end

            let(:config) do
              Config.load_from_file(cc_config_file.path, context: :worker).config_hash
            end

            it 'preserves the current_encryption_key_label value from the file' do
              expect(config[:database_encryption_keys][:current_key_label]).to eq('foo')
            end

            it 'preserves the stacks_file value from the file' do
              expect(config[:stacks_file]).to eq('/tmp/foo')
            end

            it 'preserves the maximum_app_disk_in_mb value from the file' do
              expect(config[:maximum_app_disk_in_mb]).to eq(3072)
            end

            it 'preserves the directories value from the file' do
              expect(config[:directories]).to eq({ tmpdir: '/tmp', diagnostics: '/tmp' })
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
              expect(config[:app_bits_upload_grace_period_in_seconds]).to eq(500)
            end

            it 'preserves the value of the staging auth user/password' do
              expect(config[:staging][:auth][:user]).to eq('bob')
              expect(config[:staging][:auth][:password]).to eq('laura')
            end

            it 'preserves the values of the minimum staging limits' do
              expect(config[:staging][:minimum_staging_memory_mb]).to eq(42)
              expect(config[:staging][:minimum_staging_disk_mb]).to eq(42)
              expect(config[:staging][:minimum_staging_file_descriptor_limit]).to eq(42)
            end

            it 'preserves the value of the allowed cross-origin domains' do
              expect(config[:allowed_cors_domains]).to eq(%w(http://*.appspot.com http://*.inblue.net http://talkoncorners.com http://borrowedheaven.org))
            end

            it 'preserves the backend selection configuration from the file' do
              expect(config[:users_can_select_backend]).to eq(false)
            end

            it 'preserves the enable allow ssh configuration from the file' do
              expect(config[:allow_app_ssh_access]).to eq(true)
            end

            it 'preserves the broker_client_timeout_seconds value from the file' do
              expect(config[:broker_client_timeout_seconds]).to eq(70)
            end

            it 'preserves the broker_client_default_async_poll_interval_seconds value from the file' do
              expect(config[:broker_client_default_async_poll_interval_seconds]).to eq(42)
            end

            it 'preserves the internal_service_hostname value from the file' do
              expect(config[:internal_service_hostname]).to eq('api.internal.cf')
            end

            it 'preserves the expiration values from the file' do
              expect(config[:packages][:max_valid_packages_stored]).to eq(42)
              expect(config[:droplets][:max_staged_droplets_stored]).to eq(42)
            end

            context 'when the staging auth is already url encoded' do
              let(:cc_config_file) do
                config = YAML.load_file('config/cloud_controller.yml')
                config['staging']['auth']['user'] = 'f%40t%3A%25a'
                config['staging']['auth']['password'] = 'm%40%2Fn!'

                file = Tempfile.new('cc_config.yml')
                file.write(YAML.dump(config))
                file.close
                file
              end

              let(:config_load_from_file) do
                Config.load_from_file(cc_config_file.path, context: :worker).config_hash
              end

              it 'preserves the url-encoded values' do
                config_load_from_file[:staging][:auth][:user] = 'f%40t%3A%25a'
                config_load_from_file[:staging][:auth][:password] = 'm%40%2Fn!'
              end
            end
          end

          context 'and the password contains double quotes' do
            let(:cc_config_file) do
              config = YAML.load_file('config/cloud_controller.yml')
              config['staging']['auth']['password'] = 'pass"wor"d'

              file = Tempfile.new('cc_config.yml')
              file.write(YAML.dump(config))
              file.close
              file
            end

            let(:config_load_from_file) do
              Config.load_from_file(cc_config_file.path, context: :worker).config_hash
            end

            it 'URL-encodes staging password as neccesary' do
              expect(config_load_from_file[:staging][:auth][:password]).to eq('pass%22wor%22d')
            end
          end

          context 'and the values are invalid' do
            let(:cc_config_file) do
              config = YAML.load_file('config/cloud_controller.yml')
              config['app_bits_upload_grace_period_in_seconds'] = -2345
              config['staging']['auth']['user'] = 'f@t:%a'
              config['staging']['auth']['password'] = 'm@/n!'
              config['diego']['pid_limit'] = -5

              file = Tempfile.new('cc_config.yml')
              file.write(YAML.dump(config))
              file.close
              file
            end

            let(:config_load_from_file) do
              Config.load_from_file(cc_config_file.path, context: :worker).config_hash
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
        expect(Encryptor).to receive(:db_encryption_key=).with('123-456')
        config_instance.configure_components
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

      context 'when database encryption keys are used' do
        let(:keys) do
          {
              keys: {
                  'current' => 'abc-123',
                  'previous' => 'def-456',
                  'old' => 'ghi-789'
              },
              current_key_label: 'current'
          }
        end

        let(:config_instance) do
          Config.new(test_config_hash.merge(database_encryption_keys: keys))
        end

        before do
          allow(Encryptor).to receive(:current_encryption_key_label=)
        end

        it 'sets up the current encryption key label' do
          expect(Encryptor).to receive(:current_encryption_key_label=).with(keys[:current_key_label])
          config_instance.configure_components
        end

        it 'sets up the database encryption keys' do
          expect(Encryptor).to receive(:database_encryption_keys=).with(keys[:keys])
          config_instance.configure_components
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
