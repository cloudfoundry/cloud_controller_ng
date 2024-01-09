require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Config do
    let(:test_config_hash) do
      {
        packages: {
          fog_connection: {},
          fog_aws_storage_options: {
            encryption: 'AES256'
          },
          fog_gcp_storage_options: {},
          app_package_directory_key: 'app_key'
        },
        droplets: {
          fog_connection: {},
          droplet_directory_key: 'droplet_key'
        },
        buildpacks: {
          fog_connection: {},
          buildpack_directory_key: 'bp_key'
        },
        resource_pool: {
          minimum_size: 9001,
          maximum_size: 0,
          fog_connection: {},
          resource_directory_key: 'resource_key'
        },
        external_domain: 'host',
        tls_port: 1234,
        staging: {
          auth: {
            user: 'user',
            password: 'password'
          }
        },
        reserved_private_domains: File.join(Paths::FIXTURES, 'config/reserved_private_domains.dat'),
        diego: {},
        stacks_file: 'path/to/stacks/file',
        db_encryption_key: '123-456',
        install_buildpacks: [
          {
            name: 'some-buildpack'
          }
        ]
      }
    end

    subject(:config_instance) { Config.new(test_config_hash) }

    describe '.read_file' do
      it 'raises error if the file does not exist' do
        expect do
          Config.read_file('nonexistent.yml')
        end.to raise_error(Errno::ENOENT, /No such file or directory @ rb_sysopen - nonexistent.yml/)
      end

      context 'read a file' do
        context 'when a file cannot be read' do
          let(:file_name) { 'test_config.yml' }

          it 'return an empty hash' do
            allow(VCAP::CloudController::YAMLConfig).to receive(:safe_load_file).with(file_name).and_return(nil)

            result = Config.read_file(file_name)
            expect(result).to eq({})
          end
        end

        context 'when the file has entries' do
          let(:config_contents) do
            {
              'db' => {
                'max_connections' => 2
              }
            }
          end

          let(:cc_local_worker_config_file) do
            file = Tempfile.new('cc_local_config_file.yml')
            file.write(YAML.dump(config_contents))
            file.close
            file
          end

          it 'return a valid hash' do
            config_hash = Config.read_file(cc_local_worker_config_file)
            expect(config_hash[:db][:max_connections]).to eq(2)
          end
        end

        context 'when empty YAML file is provided' do
          let(:cc_local_worker_config_file) do
            config = YAMLConfig.safe_load_file('config/cloud_controller_local_worker_override.yml')
            file = Tempfile.new('cc_local_worker_config.yml')
            file.write(YAML.dump(config))
            file.close
            file
          end

          it 'return an empty hash' do
            config_hash = Config.read_file(cc_local_worker_config_file)
            expect(config_hash).to eq({})
          end
        end
      end
    end

    describe '.load_from_hash' do
      it 'raises error if an empty hash is provided' do
        expect do
          Config.load_from_hash({}, context: :api)
        end.to raise_error(Membrane::SchemaValidationError)
      end

      context 'merges default values' do
        context 'when no config values are provided' do
          let(:cc_config_hash) do
            YAMLConfig.safe_load_file('config/cloud_controller.yml')
          end

          let(:config_hash) do
            Config.load_from_hash(cc_config_hash, context: :api).config_hash
          end

          it 'has the default values' do
            expect(config_hash[:db][:max_connections]).to eq(42)
            expect(config_hash[:name]).to eq('api')
            expect(config_hash[:local_route]).to eq('127.0.0.1')
          end
        end
      end

      context 'unit test' do
        let(:cc_config_hash) do
          {
            'some_key' => 'some-value',
            'webserver' => 'thin',
            'database_encryption' => {
              'keys' => {
                'foo' => 'bar',
                'head' => 'banging',
                'array' => %w[a b c]
              },
              'tls_port' => 123
            }
          }
        end

        it 'validates a symbolized version of the config file contents with the correct schema file' do
          allow(VCAP::CloudController::ConfigSchemas::Vms::ApiSchema).to receive(:validate)

          Config.load_from_hash(cc_config_hash).config_hash

          expect(VCAP::CloudController::ConfigSchemas::Vms::ApiSchema).to have_received(:validate).with(
            some_key: 'some-value',
            webserver: 'thin',
            database_encryption: {
              keys: {
                foo: 'bar',
                head: 'banging',
                array: %w[a b c]
              },
              tls_port: 123
            }
          )
        end

        context 'when the secrets hash is provided' do
          let(:secrets_hash) do
            {
              'some_secret' => 'shhhhh!',
              'database_encryption' => {
                'keys' => {
                  'password' => 'totes-s3cre7'
                }
              }
            }
          end

          it 'merges the secrets hash into the file contents and validates with the correct schema' do
            allow(VCAP::CloudController::ConfigSchemas::Vms::ApiSchema).to receive(:validate)

            Config.load_from_hash(cc_config_hash, context: :api, secrets_hash: secrets_hash).config_hash

            expect(VCAP::CloudController::ConfigSchemas::Vms::ApiSchema).to have_received(:validate).with(
              some_key: 'some-value',
              webserver: 'thin',
              some_secret: 'shhhhh!',
              database_encryption: {
                keys: {
                  foo: 'bar',
                  head: 'banging',
                  array: %w[a b c],
                  password: 'totes-s3cre7'
                },
                tls_port: 123
              }
            )
          end
        end
      end
    end

    describe '.load_from_file' do
      it 'raises if the file does not exist' do
        expect do
          Config.load_from_file('nonexistent.yml', context: :worker)
        end.to raise_error(Errno::ENOENT, /No such file or directory @ rb_sysopen - nonexistent.yml/)
      end

      context 'merges default values' do
        after do
          cc_config_file.unlink
        end

        context 'when no config values are provided' do
          let(:cc_config_file) do
            config = YAMLConfig.safe_load_file('config/cloud_controller.yml')
            config['db'].delete('database')

            file = Tempfile.new('cc_config.yml')
            file.write(YAML.dump(config))
            file.close
            file
          end

          let(:config) do
            Config.load_from_file(cc_config_file, context: :worker).config_hash
          end

          it 'sets a default value for database' do
            expect(config[:db][:db_connection_string]).to eq(ENV.fetch('DB_CONNECTION_STRING', nil))
            expect(config[:db][:database]).to eq(DatabasePartsParser.database_parts_from_connection(ENV.fetch('DB_CONNECTION_STRING', nil)))
          end

          context 'special passwords characters' do
            let(:uri) { "http://user:#{password}@example.com/databasename" }
            let(:raw_password) { 'pass@word' }

            context 'unescaped' do
              let(:password) { raw_password }

              it "can't handle an unescaped @" do
                expect do
                  DatabasePartsParser.database_parts_from_connection(uri)
                end.to raise_error(URI::InvalidURIError, "bad URI(is not URI?): \"#{uri}\"")
              end
            end

            context 'escaped' do
              let(:password) { CGI.escape(raw_password) }

              it "can't handle an unescaped @" do
                parts = DatabasePartsParser.database_parts_from_connection(uri)
                expect(parts[:password]).to eq(raw_password)
              end
            end
          end
        end

        context 'when config values are provided' do
          context 'and the values are valid' do
            let(:cc_config_file) do
              config = YAMLConfig.safe_load_file('config/cloud_controller.yml')
              config['stacks_file'] = '/tmp/foo'
              config['database_encryption'] = {
                'keys' => {
                  'foo' => 'bar',
                  'head' => 'banging'
                },
                'current_key_label' => 'foo'
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
              expect(config[:database_encryption][:current_key_label]).to eq('foo')
            end

            it 'preserves the stacks_file value from the file' do
              expect(config[:stacks_file]).to eq('/tmp/foo')
            end

            it 'preserves the external_protocol value from the file' do
              expect(config[:external_protocol]).to eq('http')
            end

            it 'preserves the request_timeout_in_seconds value from the file' do
              expect(config[:request_timeout_in_seconds]).to eq(600)
            end

            it 'preserves the threadpool_size value from the file' do
              expect(config[:threadpool_size]).to eq(20)
            end

            it 'preserves the value of the staging auth user/password' do
              expect(config[:staging][:auth][:user]).to eq('bob')
              expect(config[:staging][:auth][:password]).to eq('laura')
            end

            it 'preserves the values of the minimum staging limits' do
              expect(config[:staging][:minimum_staging_disk_mb]).to eq(42)
            end

            it 'preserves the enable allow ssh configuration from the file' do
              expect(config[:allow_app_ssh_access]).to be(true)
            end

            it 'preserves the internal_service_hostname value from the file' do
              expect(config[:internal_service_hostname]).to eq('api.internal.cf')
            end

            context 'when the staging auth is already url encoded' do
              let(:cc_config_file) do
                config = YAMLConfig.safe_load_file('config/cloud_controller.yml')
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
              config = YAMLConfig.safe_load_file('config/cloud_controller.yml')
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
              config = YAMLConfig.safe_load_file('config/cloud_controller.yml')
              config['staging']['auth']['user'] = 'f@t:%a'
              config['staging']['auth']['password'] = 'm@/n!'

              file = Tempfile.new('cc_config.yml')
              file.write(YAML.dump(config))
              file.close
              file
            end

            let(:config_load_from_file) do
              Config.load_from_file(cc_config_file.path, context: :worker).config_hash
            end

            it 'URL-encodes staging auth as necessary' do
              expect(config_load_from_file[:staging][:auth][:user]).to eq('f%40t%3A%25a')
              expect(config_load_from_file[:staging][:auth][:password]).to eq('m%40%2Fn%21')
            end
          end

          context 'unit test' do
            let(:config_contents) do
              {
                'some_key' => 'some-value',
                'database_encryption' => {
                  'keys' => {
                    'foo' => 'bar',
                    'head' => 'banging',
                    'array' => %w[a b c]
                  },
                  'current_key_label' => 'foo'
                }
              }
            end
            let(:cc_config_file) do
              file = Tempfile.new('cc_config.yml')
              file.write(YAML.dump(config_contents))
              file.close
              file
            end

            it 'validates a symbolized version of the config file contents with the correct schema file' do
              allow(VCAP::CloudController::ConfigSchemas::Vms::WorkerSchema).to receive(:validate)

              Config.load_from_file(cc_config_file.path, context: :worker).config_hash

              expect(VCAP::CloudController::ConfigSchemas::Vms::WorkerSchema).to have_received(:validate).with(
                some_key: 'some-value',
                database_encryption: {
                  keys: {
                    foo: 'bar',
                    head: 'banging',
                    array: %w[a b c]
                  },
                  current_key_label: 'foo'
                }
              )
            end

            context 'when the secrets hash is provided' do
              let(:secrets_hash) do
                {
                  'some_secret' => 'shhhhh!',
                  'database_encryption' => {
                    'keys' => {
                      'password' => 'totes-s3cre7'
                    }
                  }
                }
              end

              it 'merges the secrets hash into the file contents and validates with the correct schema' do
                allow(VCAP::CloudController::ConfigSchemas::Vms::WorkerSchema).to receive(:validate)

                Config.load_from_file(cc_config_file.path, context: :worker, secrets_hash: secrets_hash).config_hash

                expect(VCAP::CloudController::ConfigSchemas::Vms::WorkerSchema).to have_received(:validate).with(
                  some_key: 'some-value',
                  some_secret: 'shhhhh!',
                  database_encryption: {
                    keys: {
                      foo: 'bar',
                      head: 'banging',
                      array: %w[a b c],
                      password: 'totes-s3cre7'
                    },
                    current_key_label: 'foo'
                  }
                )
              end
            end

            context 'when the config has no "kubernetes" key' do
              let(:config_contents) do
                { 'some_non_kubernetes_key' => true }
              end

              it 'uses the Vms schema to validate the config' do
                allow(VCAP::CloudController::ConfigSchemas::Vms::ApiSchema).to receive(:validate)
                Config.load_from_file(cc_config_file.path, context: :api).config_hash

                expect(VCAP::CloudController::ConfigSchemas::Vms::ApiSchema).to have_received(:validate)
              end
            end
          end
        end
      end
    end

    describe '#configure_components' do
      let(:dependency_locator) { CloudController::DependencyLocator.instance }
      let(:test_config_hash) do
        {
          packages: {
            fog_connection: {},
            fog_aws_storage_options: {
              encryption: 'AES256'
            },
            fog_gcp_storage_options: {},
            app_package_directory_key: 'app_key'
          },
          droplets: {
            fog_connection: {},
            droplet_directory_key: 'droplet_key'
          },
          buildpacks: {
            fog_connection: {},
            buildpack_directory_key: 'bp_key'
          },
          resource_pool: {
            minimum_size: 9001,
            maximum_size: 0,
            fog_connection: {},
            resource_directory_key: 'resource_key'
          },
          external_host: 'host',
          tls_port: 1234,
          staging: {
            auth: {
              user: 'user',
              password: 'password'
            }
          },

          reserved_private_domains: File.join(Paths::FIXTURES, 'config/reserved_private_domains.dat'),
          diego: {},
          stacks_file: 'path/to/stacks/file',
          db_encryption_key: '123-456'
        }
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
        expect(ProcessObserver).to receive(:configure).with(instance_of(Stagers), instance_of(Runners))

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
          expect(GC::Profiler.enabled?).to be(false)
        end
      end

      context 'when database encryption keys are used' do
        let(:keys) do
          {
            keys: {
              current: 'abc-123',
              previous: 'def-456',
              old: 'ghi-789'
            },
            current_key_label: 'current',
            pbkdf2_hmac_iterations: 100_020
          }
        end

        let(:config_instance) do
          Config.new(test_config_hash.merge(database_encryption: keys))
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

        it 'sets up pbkdf2_hmac_iterations' do
          expect(Encryptor).to receive(:pbkdf2_hmac_iterations=).with(keys[:pbkdf2_hmac_iterations])
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
          expect(GC::Profiler.enabled?).to be(true)
        end
      end

      it 'sets up the reserved private domain' do
        expect(PrivateDomain).to receive(:configure).with(test_config_hash[:reserved_private_domains])
        config_instance.configure_components
      end
    end

    describe '#get' do
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
                                                       fog_gcp_storage_options: {},
                                                       app_package_directory_key: 'app_key'
                                                     })
        expect(config_instance.get(:packages, :fog_aws_storage_options)).to eq(encryption: 'AES256')
      end

      it 'raises an exception when given an invalid key' do
        expect do
          config_instance.get(:blub_blub)
        end.to raise_error Config::InvalidConfigPath, /"blub_blub" is not a valid config key/
      end

      it 'raises when you dig into a leaf property' do
        expect do
          config_instance.get(:external_domain, :pantaloons)
        end.to raise_error Config::InvalidConfigPath, /"external_domain.pantaloons" is not a valid config key/
      end

      it 'raises when you dig into hashes' do
        expect do
          config_instance.get(:packages, :fog_aws_storage_options, :encryption)
        end.to raise_error Config::InvalidConfigPath, /"packages.fog_aws_storage_options.encryption" is not a valid config key/
      end

      it 'raises when given a path with an invalid key' do
        expect do
          config_instance.get(:packages, :ham_sandwich)
        end.to raise_error Config::InvalidConfigPath, /"packages.ham_sandwich" is not a valid config key/
      end

      it 'raises when you dig into arrays' do
        expect do
          config_instance.get(:install_buildpacks, :name)
        end.to raise_error Config::InvalidConfigPath, /"install_buildpacks.name" is not a valid config key/
      end
    end

    describe '#set' do
      it 'saves the value at the key in the config' do
        config_instance.set(:external_host, 'foobar.example.com')
        expect(config_instance.get(:external_host)).to eq 'foobar.example.com'
      end
    end

    describe 'broker_client_async_poll_exponential_backoff_rate' do
      let(:cc_config_file) do
        config = YAMLConfig.safe_load_file('config/cloud_controller.yml')
        config['broker_client_async_poll_exponential_backoff_rate'] = backoff_rate

        file = Tempfile.new('cc_config.yml')
        file.write(YAML.dump(config))
        file.close
        file
      end

      let(:config) do
        Config.load_from_file(cc_config_file, context: schema_context)
      end

      context 'worker schema' do
        let(:schema_context) { :worker }

        context 'when given an Integer' do
          let(:backoff_rate) { 1 }

          it 'succeeds' do
            expect(config.get(:broker_client_async_poll_exponential_backoff_rate)).to eq 1
          end
        end

        context 'when given a Float' do
          let(:backoff_rate) { 1.0 }

          it 'succeeds' do
            expect(config.get(:broker_client_async_poll_exponential_backoff_rate)).to eq 1
          end
        end
      end

      context 'api schema' do
        let(:schema_context) { :api }

        context 'when given an Integer' do
          let(:backoff_rate) { 1 }

          it 'succeeds' do
            expect(config.get(:broker_client_async_poll_exponential_backoff_rate)).to eq 1
          end
        end

        context 'when given a Float' do
          let(:backoff_rate) { 1.0 }

          it 'succeeds' do
            expect(config.get(:broker_client_async_poll_exponential_backoff_rate)).to eq 1
          end
        end
      end
    end
  end
end
