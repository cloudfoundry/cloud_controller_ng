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
      it_should_be_removed(
        by: '2019/07/13',
        explanation: 'Database parts can now be renamed to database. See story: #158544649'
      )

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
          let(:cc_config_file) do
            config = YAML.load_file('config/cloud_controller.yml')
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
            expect(config[:db][:database]).to eq(ENV['DB_CONNECTION_STRING'])
            expect(config[:db][:database_parts]).to eq(DatabasePartsParser.database_parts_from_connection(ENV['DB_CONNECTION_STRING']))
          end

          context 'special passwords characters' do
            let(:uri) { "http://user:#{password}@example.com/databasename" }
            let(:raw_password) { 'pass@word' }

            context 'unescaped' do
              let(:password) { raw_password }

              it "can't handle an unescaped @" do
                expect {
                  DatabasePartsParser.database_parts_from_connection(uri)
                }.to raise_error(URI::InvalidURIError, "bad URI(is not URI?): #{uri}")
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
              config = YAML.load_file('config/cloud_controller.yml')
              config['stacks_file'] = '/tmp/foo'
              config['database_encryption'] = {
                keys: {
                  foo: 'bar',
                  head: 'banging'
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

            it 'preserves the value of the staging auth user/password' do
              expect(config[:staging][:auth][:user]).to eq('bob')
              expect(config[:staging][:auth][:password]).to eq('laura')
            end

            it 'preserves the values of the minimum staging limits' do
              expect(config[:staging][:minimum_staging_disk_mb]).to eq(42)
            end

            it 'preserves the enable allow ssh configuration from the file' do
              expect(config[:allow_app_ssh_access]).to eq(true)
            end

            it 'preserves the internal_service_hostname value from the file' do
              expect(config[:internal_service_hostname]).to eq('api.internal.cf')
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
          expect(GC::Profiler.enabled?).to eq(false)
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
              current_key_label: 'current'
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
