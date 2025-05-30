require 'spec_helper'
require 'messages/app_manifest_message'

module VCAP::CloudController
  RSpec.describe AppManifestMessage do
    describe 'validations' do
      context 'when unexpected keys are requested' do
        let(:params_from_yaml) { { instances: 3, memory: '2G', name: 'foo' } }

        it 'is valid' do
          message = AppManifestMessage.create_from_yml(params_from_yaml)

          expect(message).to be_valid
        end
      end

      context 'when name is not specified' do
        let(:params_from_yaml) { { instances: 3, memory: '2G' } }

        it 'is not valid' do
          message = AppManifestMessage.create_from_yml(params_from_yaml)

          expect(message).not_to be_valid
          expect(message.errors).to have(2).items
          expect(message.errors.full_messages[0]).to match(/^Name must not be empty/)
        end
      end

      describe 'memory' do
        context 'when memory unit is not part of expected set of values' do
          let(:params_from_yaml) { { name: 'eugene', memory: '200INVALID' } }

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include(
              'Process "web": Memory must use a supported unit: B, K, KB, M, MB, G, GB, T, or TB'
            )
          end
        end

        context 'when memory is not a positive amount' do
          let(:params_from_yaml) { { name: 'eugene', memory: '-1MB' } }

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include('Process "web": Memory must be greater than 0MB')
          end
        end

        context 'when memory is in bytes' do
          let(:params_from_yaml) { { name: 'eugene', memory: '-35B' } }

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include('Process "web": Memory must be greater than 0MB')
          end
        end
      end

      describe 'disk_quota' do
        context 'when disk_quota unit is not part of expected set of values' do
          let(:params_from_yaml) { { name: 'eugene', disk_quota: '200INVALID' } }

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include(
              'Process "web": Disk quota must use a supported unit: B, K, KB, M, MB, G, GB, T, or TB'
            )
          end
        end

        context 'when disk_quota is zero' do
          let(:params_from_yaml) { { name: 'eugene', disk_quota: 0 } }

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include(
              'Process "web": Disk quota must use a supported unit: B, K, KB, M, MB, G, GB, T, or TB'
            )
          end
        end

        context 'when disk_quota is not a positive amount' do
          let(:params_from_yaml) { { name: 'eugene', disk_quota: '-1MB' } }

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include('Process "web": Disk quota must be greater than 0MB')
          end
        end

        context 'when disk_quota is not numeric' do
          let(:params_from_yaml) { { name: 'eugene', disk_quota: 'gerg herscheiser' } }

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include('Process "web": Disk quota is not a number')
          end
        end
      end

      describe 'log-rate-limit-per-second' do
        context 'when log-rate-limit-per-second unit is not part of expected set of values' do
          let(:params_from_yaml) { { name: 'eugene', log_rate_limit_per_second: '200INVALID' } }

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include(
              'Process "web": Log rate limit per second must use a supported unit: B, K, KB, M, MB, G, GB, T, or TB'
            )
          end
        end

        context 'when log-rate-limit-per-second is less than -1 bytes' do
          let(:params_from_yaml) { { name: 'eugene', log_rate_limit_per_second: '-1M' } }

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include('Process "web": Log rate limit must be an integer greater than or equal to -1')
          end
        end

        context 'when log-rate-limit-per-second is not numeric' do
          let(:params_from_yaml) { { name: 'eugene', log_rate_limit_per_second: 'gerg herscheisers' } }

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include(
              'Process "web": Log rate limit per second is not a number'
            )
          end
        end

        context 'when log-rate-limit-per-second is an unlimited amount' do
          context 'specified as -1' do
            let(:params_from_yaml) { { name: 'eugene', 'log-rate-limit-per-second' => '-1' } }

            it 'is valid' do
              message = AppManifestMessage.create_from_yml(params_from_yaml)
              expect(message).to be_valid
            end
          end

          context 'specified as the number -1' do
            let(:params_from_yaml) { { name: 'eugene', 'log-rate-limit-per-second' => -1 } }

            it 'is valid' do
              message = AppManifestMessage.create_from_yml(params_from_yaml)
              expect(message).to be_valid
            end
          end

          context 'with a bytes suffix' do
            let(:params_from_yaml) { { name: 'eugene', log_rate_limit_per_second: '-1B' } }

            it 'is valid' do
              message = AppManifestMessage.create_from_yml(params_from_yaml)
              expect(message).to be_valid
            end
          end
        end

        context 'when log-rate-limit-per-second is in megabytes' do
          let(:params_from_yaml) { { name: 'eugene', log_rate_limit_per_second: '1MB' } }

          it 'is valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)
            expect(message).to be_valid
          end
        end

        context 'when log-rate-limit-per-second is 0' do
          let(:params_from_yaml) { { name: 'eugene', log_rate_limit_per_second: '0' } }

          it 'is valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)
            expect(message).to be_valid
            expect(message.manifest_process_scale_messages.first.log_rate_limit).to eq(0)
          end
        end

        context 'when log-rate-limit-per-second is the number 0' do
          let(:params_from_yaml) { { name: 'eugene', log_rate_limit_per_second: 0 } }

          it 'is valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)
            expect(message).to be_valid
            expect(message.manifest_process_scale_messages.first.log_rate_limit).to eq(0)
          end
        end

        context 'when log-rate-limit-per-second is 0TB' do
          let(:params_from_yaml) { { name: 'eugene', log_rate_limit_per_second: '0TB' } }

          it 'is valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)
            expect(message).to be_valid
            expect(message.manifest_process_scale_messages.first.log_rate_limit).to eq(0)
          end
        end

        context 'when log-rate-limit-per-second is a positive integer without a suffix' do
          let(:params_from_yaml) { { name: 'eugene', log_rate_limit_per_second: 9999 } }

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include(
              'Process "web": Log rate limit per second must use a supported unit: B, K, KB, M, MB, G, GB, T, or TB'
            )
          end
        end
      end

      describe 'buildpack' do
        context 'when providing a valid buildpack name' do
          let(:buildpack) { Buildpack.make }
          let(:params_from_yaml) { { name: 'eugene', buildpack: buildpack.name } }

          it 'is valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).to be_valid
          end
        end

        context 'when the buildpack is not a string' do
          let(:params_from_yaml) { { name: 'eugene', buildpack: 99 } }

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include('Buildpack must be a string')
          end
        end

        context 'when the buildpack has fewer than 0 characters' do
          let(:params_from_yaml) { { name: 'eugene', buildpack: '' } }

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include('Buildpack must be between 1 and 4096 characters')
          end
        end

        context 'when the buildpack has more than 4096 characters' do
          let(:params_from_yaml) { { name: 'eugene', buildpack: 'a' * 4097 } }

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include('Buildpack must be between 1 and 4096 characters')
          end
        end
      end

      describe 'buildpacks' do
        context 'when providing valid buildpack names' do
          let(:buildpack) { Buildpack.make }
          let(:buildpack2) { Buildpack.make }
          let(:params_from_yaml) { { name: 'eugene', buildpacks: [buildpack.name, buildpack2.name] } }

          it 'is valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).to be_valid
          end
        end

        context 'when one of the buildpacks is not a string' do
          let(:buildpack) { Buildpack.make }
          let(:params_from_yaml) { { name: 'eugene', buildpacks: [buildpack.name, 99] } }

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include('Buildpacks can only contain strings')
          end
        end

        context 'when both buildpack and buildpacks are requested' do
          let(:buildpack) { Buildpack.make }
          let(:params_from_yaml) { { name: 'eugene', buildpacks: [buildpack.name], buildpack: 'some-buildpack' } }

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include('Buildpack and Buildpacks fields cannot be used together.')
          end
        end
      end

      describe 'docker' do
        let(:params_from_yaml) { { name: 'eugene', docker: { image: 'my/image' } } }

        context 'when docker is enabled' do
          before do
            FeatureFlag.make(name: 'diego_docker', enabled: true, error_message: nil)
          end

          it 'is valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).to be_valid
          end
        end

        context 'when docker is disabled' do
          before do
            FeatureFlag.make(name: 'diego_docker', enabled: false, error_message: 'I am a banana')
          end

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include('Feature Disabled: I am a banana')
          end
        end
      end

      describe 'stack' do
        context 'when providing a valid stack name' do
          let(:params_from_yaml) { { name: 'eugene', stack: 'cflinuxfs4' } }

          it 'is valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).to be_valid
            expect(message.stack).to eq('cflinuxfs4')
          end
        end

        context 'when the stack is not a string' do
          let(:params_from_yaml) { { name: 'eugene', stack: 99 } }

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include('Stack must be a string')
          end
        end
      end

      describe 'instances' do
        context 'when instances is not an number' do
          let(:params_from_yaml) { { name: 'eugene', instances: 'silly string thing' } }

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include('Process "web": Instances is not a number')
          end
        end

        context 'when instances is not an integer' do
          let(:params_from_yaml) { { name: 'eugene', instances: 3.5 } }

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include('Process "web": Instances must be an integer')
          end
        end

        context 'when instances is not a positive integer' do
          let(:params_from_yaml) { { name: 'eugene', instances: -1 } }

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include('Process "web": Instances must be greater than or equal to 0')
          end
        end
      end

      describe 'env' do
        context 'when env is not an object' do
          let(:params_from_yaml) do
            {
              name: 'eugene',
              env: 'im a non-hash'
            }
          end

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)
            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include('Env must be an object of keys and values')
          end
        end

        context 'when env has bad keys' do
          let(:params_from_yaml) do
            {
              name: 'eugene',
              env: {
                "": 'null-key',
                VCAP_BAD_KEY: 1,
                VMC_BAD_KEY: %w[hey it's an array],
                PORT: 5
              }
            }
          end

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)
            expect(message).not_to be_valid
            expect(message.errors).to have(4).items
            expect(message.errors.full_messages).to contain_exactly('Env cannot set PORT', 'Env cannot start with VCAP_', 'Env cannot start with VMC_',
                                                                    'Env key must be a minimum length of 1')
          end
        end
      end

      describe 'routes' do
        context 'when all routes are valid' do
          let(:params_from_yaml) do
            {
              name: 'eugene',
              routes: [
                { route: 'existing.example.com', protocol: 'http2' },
                { route: 'new.example.com' }
              ]
            }
          end

          it 'returns true' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).to be_valid
          end
        end

        context 'when a route uri is invalid' do
          let(:params_from_yaml) do
            {
              name: 'eugene',
              routes:
              [
                { route: 'blah' },
                { route: 'anotherblah' },
                { route: 'http://example.com' }
              ]
            }
          end

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).not_to be_valid
            expect(message.errors.full_messages).to contain_exactly("The route 'anotherblah' is not a properly formed URL", "The route 'blah' is not a properly formed URL")
          end
        end

        context 'when routes are malformed' do
          let(:params_from_yaml) { { name: 'eugene', routes: ['blah'] } }

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).not_to be_valid
            expect(message.errors.full_messages).to contain_exactly('Routes must be a list of route objects')
          end
        end

        context 'when no-route is specified' do
          let(:params_from_yaml) { { name: 'eugene', 'no-route' => no_route_val } }

          context 'when no-route is true' do
            let(:no_route_val) { true }

            it 'is valid' do
              message = AppManifestMessage.create_from_yml(params_from_yaml)
              expect(message).to be_valid
            end
          end

          context 'when no-route is not a boolean' do
            let(:no_route_val) { 'I am a free s0mjgnbha' }

            it 'is not valid' do
              message = AppManifestMessage.create_from_yml(params_from_yaml)
              expect(message).not_to be_valid
              expect(message.errors.full_messages).to contain_exactly('No-route must be a boolean')
            end
          end

          context 'when no-route is true and routes are specified' do
            let(:params_from_yaml) do
              {
                name: 'eugene',
                no_route: true,
                routes:
                  [
                    { route: 'http://example.com' }
                  ]
              }
            end

            it 'is valid' do
              message = AppManifestMessage.create_from_yml(params_from_yaml)
              expect(message).to be_valid
            end
          end
        end

        context 'when random_route is specified' do
          let(:params_from_yaml) { { name: 'eugene', 'random_route' => random_route_val } }

          context 'when random_route is true' do
            let(:random_route_val) { true }

            it 'is valid' do
              message = AppManifestMessage.create_from_yml(params_from_yaml)
              expect(message).to be_valid
            end
          end

          context 'when random_route is not a boolean' do
            let(:random_route_val) { 'I am a free s0mjgnbha' }

            it 'is not valid' do
              message = AppManifestMessage.create_from_yml(params_from_yaml)
              expect(message).not_to be_valid
              expect(message.errors.full_messages).to contain_exactly('Random-route must be a boolean')
            end
          end

          context 'when random_route is true and routes are specified' do
            let(:params_from_yaml) do
              {
                name: 'eugene',
                random_route: true,
                routes:
                  [
                    { route: 'http://example.com' }
                  ]
              }
            end

            it 'is valid' do
              message = AppManifestMessage.create_from_yml(params_from_yaml)
              expect(message).to be_valid
            end
          end
        end

        context 'when default_route is specified' do
          let(:params_from_yaml) { { name: 'eugene', 'default_route' => default_route_val } }

          context 'when default_route is true' do
            let(:default_route_val) { true }

            it 'is valid' do
              message = AppManifestMessage.create_from_yml(params_from_yaml)
              expect(message).to be_valid
            end
          end

          context 'when default_route is not a boolean' do
            let(:default_route_val) { 'I am a free s0mjgnbha' }

            it 'is not valid' do
              message = AppManifestMessage.create_from_yml(params_from_yaml)
              expect(message).not_to be_valid
              expect(message.errors.full_messages).to contain_exactly('Default-route must be a boolean')
            end
          end

          context 'when default_route is true and routes are specified' do
            let(:params_from_yaml) do
              {
                name: 'eugene',
                default_route: true,
                routes:
                  [
                    { route: 'http://example.com' }
                  ]
              }
            end

            it 'is valid' do
              message = AppManifestMessage.create_from_yml(params_from_yaml)
              expect(message).to be_valid
            end
          end
        end
      end

      describe 'services bindings' do
        context 'when services is not an array' do
          let(:params_from_yaml) do
            {
              name: 'eugene',
              services: 'string'
            }
          end

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)
            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include('Services must be a list of service instances')
          end
        end
      end

      describe 'processes' do
        context 'when processes is not an array' do
          let(:params_from_yaml) { { name: 'eugene', processes: 'string' } }

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)
            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include('Processes must be an array of process configurations')
          end
        end

        context 'when any process does not have a type' do
          let(:params_from_yaml) { { name: 'eugene', processes: [{ 'instances' => 3 }] } }

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)
            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include('All Processes must specify a type')
          end
        end

        context 'when any process has a blank type' do
          let(:params_from_yaml) { { name: 'eugene', processes: [{ 'type' => '', 'instances' => 3 }, { 'type' => nil, 'instances' => 2 }] } }

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)
            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include('All Processes must specify a type')
          end
        end

        context 'when any process fails validation' do
          let(:params_from_yaml) { { name: 'eugene', processes: [{ 'type' => 'totally-a-type', 'instances' => -1, 'timeout' => -5 }] } }

          it 'has the type of the process in the error message' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)
            expect(message).not_to be_valid
            expect(message.errors).to have(2).items
            expect(message.errors.full_messages).to include('Process "totally-a-type": Instances must be greater than or equal to 0')
            expect(message.errors.full_messages).to include('Process "totally-a-type": Timeout must be greater than or equal to 1')
          end

          context 'when processes attributes are invalid' do
            let(:process1) do
              {
                'type' => 'type1',
                'instances' => -30,
                'memory' => 'potato',
                'disk_quota' => '100',
                'log-rate-limit-per-second' => 'kumara',
                'health_check_type' => 'sweet_potato',
                'health_check_http_endpoint' => '/healthcheck_potato',
                'health_check_invocation_timeout' => 'yucca',
                'health_check_interval' => 'yucca',
                'readiness_health_check_type' => 'meow-tuber',
                'readiness_health_check_invocation_timeout' => -8,
                'readiness_health_check_http_endpoint' => 'potato potahto',
                'readiness_health_check_interval' => 'yucca',
                'command' => '',
                'timeout' => 'yam'
              }
            end
            let(:process2) do
              {
                'type' => 'type2',
                'instances' => 'cassava',
                'memory' => 'potato',
                'disk_quota' => '100',
                'log-rate-limit-per-second' => '100',
                'health_check_type' => 'sweet_potato',
                'health_check_http_endpoint' => '/healthcheck_potato',
                'health_check_invocation_timeout' => 'yucca',
                'health_check_interval' => -1,
                'readiness_health_check_invocation_timeout' => 'cat-jicima',
                'readiness_health_check_interval' => -1,
                'command' => '',
                'timeout' => 'yam'
              }
            end
            let(:params_from_yaml) do
              {
                name: 'eugene',
                processes: [process1, process2]
              }
            end

            it 'includes the type of the process in the error message' do
              message = AppManifestMessage.create_from_yml(params_from_yaml)
              expect(message).not_to be_valid
              expect(message.errors).to have(27).items

              expected_errors = [
                'Process "type1": Command must be between 1 and 4096 characters',
                'Process "type1": Disk quota must use a supported unit: B, K, KB, M, MB, G, GB, T, or TB',
                'Process "type1": Log rate limit per second is not a number',
                'Process "type1": Instances must be greater than or equal to 0',
                'Process "type1": Memory is not a number',
                'Process "type1": Timeout is not a number',
                'Process "type1": Health check type must be "port", "process", or "http"',
                'Process "type1": Health check type must be "http" to set a health check HTTP endpoint',
                'Process "type1": Health check invocation timeout is not a number',
                'Process "type1": Health check interval is not a number',
                'Process "type1": Readiness health check interval is not a number',
                'Process "type1": Readiness health check type must be "port", "process", or "http"',
                'Process "type1": Readiness health check invocation timeout must be greater than or equal to 1',
                'Process "type1": Readiness health check http endpoint must be a valid URI path',
                'Process "type1": Readiness health check type must be "http" to set a health check HTTP endpoint',
                'Process "type2": Command must be between 1 and 4096 characters',
                'Process "type2": Disk quota must use a supported unit: B, K, KB, M, MB, G, GB, T, or TB',
                'Process "type2": Log rate limit per second must use a supported unit: B, K, KB, M, MB, G, GB, T, or TB',
                'Process "type2": Instances is not a number',
                'Process "type2": Memory is not a number',
                'Process "type2": Timeout is not a number',
                'Process "type2": Health check type must be "port", "process", or "http"',
                'Process "type2": Health check type must be "http" to set a health check HTTP endpoint',
                'Process "type2": Health check invocation timeout is not a number',
                'Process "type2": Readiness health check invocation timeout is not a number',
                'Process "type2": Health check interval must be greater than or equal to 1',
                'Process "type2": Readiness health check interval must be greater than or equal to 1'
              ]

              expect(message.errors.full_messages).to match_array(expected_errors)
            end
          end
        end

        context 'when there is more than one process with the same type' do
          let(:params_from_yaml) do
            { name: 'eugene', processes: [{ 'type' => 'foo', 'instances' => 3 }, { 'type' => 'foo', 'instances' => 1 },
                                          { 'type' => 'bob', 'instances' => 5 }, { 'type' => 'bob', 'instances' => 1 }] }
          end

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)
            expect(message).not_to be_valid
            expect(message.errors).to have(2).items
            expect(message.errors.full_messages).to include('Process "foo" may only be present once')
            expect(message.errors.full_messages).to include('Process "bob" may only be present once')
          end
        end

        context 'log-rate-limit-per-second' do
          context 'when log-rate-limit-per-second is an unlimited amount' do
            context 'specified as -1' do
              let(:params_from_yaml) { { name: 'eugene', processes: [{ 'type' => 'foo', 'log-rate-limit-per-second' => '-1' }] } }

              it 'is valid' do
                message = AppManifestMessage.create_from_yml(params_from_yaml)
                expect(message).to be_valid
                expect(message.manifest_process_scale_messages.first.log_rate_limit).to eq(-1)
              end
            end

            context 'with a bytes suffix' do
              let(:params_from_yaml) { { name: 'eugene', processes: [{ 'type' => 'foo', 'log-rate-limit-per-second' => '-1B' }] } }

              it 'is valid' do
                message = AppManifestMessage.create_from_yml(params_from_yaml)
                expect(message).to be_valid
              end
            end
          end
        end
      end

      describe 'sidecars' do
        context 'when sidecars is not an array' do
          let(:params_from_yaml) { { name: 'eugene', sidecars: 'string' } }

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)
            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include('Sidecars must be an array of sidecar configurations')
          end
        end

        context 'when sidecars name is empty string' do
          let(:params_from_yaml) do
            {
              name: 'eugene',
              sidecars: [{ name: '', command: 'rackup', process_types: ['web'] }]
            }
          end

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)
            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include('Sidecar name can\'t be blank')
          end
        end

        context 'when sidecars command is empty string' do
          let(:params_from_yaml) do
            {
              name: 'eugene',
              sidecars: [{ name: 'my_sidecar', command: '', process_types: ['web'] }]
            }
          end

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)
            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include('Sidecar "my_sidecar": Command can\'t be blank')
          end
        end

        context 'when sidecars name is not supplied' do
          let(:params_from_yaml) do
            {
              name: 'eugene',
              sidecars: [{ command: 'rackup', process_types: ['web'] }]
            }
          end

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)
            expect(message).not_to be_valid
            expect(message.errors).to have(2).items
            expect(message.errors.full_messages).to include('Sidecar name can\'t be blank')
            expect(message.errors.full_messages).to include('Sidecar name must be a string')
          end
        end

        context 'when sidecars memory is not numeric' do
          let(:params_from_yaml) do
            {
              name: 'eugene',
              sidecars: [{ command: 'rackup', process_types: ['web'], name: 'sylvester', memory: 'selective' }]
            }
          end

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)
            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include('Sidecar "sylvester": Memory in mb is not a number')
          end
        end

        context 'when the sidecars are valid' do
          let(:params_from_yaml) do
            {
              name: 'eugene',
              sidecars: [{ command: 'rackup', process_types: ['web'], name: 'sylvester', memory: '38M' },
                         { command: 'rackup', process_types: ['web'], name: 'cookie', memory: '2G' }]
            }
          end

          it 'is valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)
            expect(message).to be_valid
            expect(message.sidecars.size).to eq(2)
          end
        end
      end

      describe 'metadata' do
        context 'when metadata is not an object' do
          let(:params_from_yaml) do
            {
              name: 'eugene',
              metadata: 'im a non-hash'
            }
          end

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)
            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include('Metadata must be an object')
          end
        end

        context 'when metadata.labels is not an object' do
          let(:params_from_yaml) do
            {
              name: 'eugene',
              metadata: {
                labels: 'im a non-hash'
              }
            }
          end

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)
            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors_on(:metadata)).to include("'labels' is not an object")
          end
        end

        context 'when metadata.labels has invalid keys' do
          let(:params_from_yaml) do
            {
              name: 'eugene',
              metadata: {
                labels: { nil => 'value' }
              }
            }
          end

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)
            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors_on(:metadata)).to contain_exactly('label key error: key cannot be empty string')
          end
        end

        context 'when metadata.labels has invalid values' do
          let(:params_from_yaml) do
            {
              name: 'eugene',
              metadata: {
                labels: {
                  'k1' => 'no spaces or ! allowed'
                }
              }
            }
          end

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)
            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors_on(:metadata)).to contain_exactly("label value error: 'no spaces or ! allowed' contains invalid characters")
          end
        end

        context 'when metadata.annotations is not an object' do
          let(:params_from_yaml) do
            {
              name: 'eugene',
              metadata: {
                annotations: 'im a non-hash'
              }
            }
          end

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)
            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors_on(:metadata)).to include("'annotations' is not an object")
          end
        end

        context 'when metadata.annotations has invalid keys' do
          let(:params_from_yaml) do
            {
              name: 'eugene',
              metadata: {
                annotations: { 'x' * 1000 => 'value' }
              }
            }
          end

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)
            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors_on(:metadata)).to contain_exactly("annotation key error: 'xxxxxxxx...' is greater than 63 characters")
          end
        end

        context 'when metadata.annotations has invalid values' do
          let(:params_from_yaml) do
            {
              name: 'eugene',
              metadata: {
                annotations: {
                  'too-large-value' => 'oversize-' + ('x' * 5000)
                }
              }
            }
          end

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)
            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors_on(:metadata)).to contain_exactly("annotation value error: 'oversize...' is greater than 5000 characters")
          end
        end
      end

      describe 'combination errors' do
        context 'when docker and buildpack is provided' do
          before do
            FeatureFlag.make(name: 'diego_docker', enabled: true, error_message: nil)
          end

          let(:buildpack) { Buildpack.make }
          let(:params_from_yaml) { { name: 'eugene', buildpack: buildpack.name, docker: { image: 'my/image' } } }

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).not_to be_valid

            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include('Cannot specify both buildpack(s) and docker keys')
          end
        end

        context 'when docker and buildpacks is provided' do
          before do
            FeatureFlag.make(name: 'diego_docker', enabled: true, error_message: nil)
          end

          let(:buildpack) { Buildpack.make }
          let(:buildpack2) { Buildpack.make }
          let(:params_from_yaml) { { name: 'eugene', buildpacks: [buildpack.name, buildpack2.name], docker: { image: 'my/image' } } }

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(params_from_yaml)

            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include('Cannot specify both buildpack(s) and docker keys')
          end
        end
      end

      context 'when there are multiple errors' do
        let(:params_from_yaml) do
          {
            name: 'eugene',
            instances: -1,
            memory: 120,
            disk_quota: '-120KB',
            buildpack: 99,
            stack: 42,
            env: %w[not an object]
          }
        end

        it 'is not valid' do
          message = AppManifestMessage.create_from_yml(params_from_yaml)

          expect(message).not_to be_valid
          error_messages = ['Process "web": Instances must be greater than or equal to 0',
                            'Process "web": Memory must use a supported unit: B, K, KB, M, MB, G, GB, T, or TB',
                            'Process "web": Disk quota must be greater than 0MB',
                            'Buildpack must be a string',
                            'Stack must be a string',
                            'Env must be an object of keys and values']
          expect(message.errors.full_messages).to match_array(error_messages)
        end
      end
    end

    describe '.create_from_yml' do
      let(:parsed_yaml) { { 'name' => 'blah', 'instances' => 4, 'memory' => '200GB' } }

      it 'returns the correct AppManifestMessage' do
        message = AppManifestMessage.create_from_yml(parsed_yaml)

        expect(message).to be_valid
        expect(message).to be_a(AppManifestMessage)
        expect(message.instances).to eq(4)
        expect(message.memory).to eq('200GB')
      end

      it 'converts requested keys to symbols' do
        message = AppManifestMessage.create_from_yml(parsed_yaml)

        expect(message).to be_requested(:instances)
        expect(message).to be_requested(:memory)
      end
    end

    describe '.underscore_keys' do
      let(:parsed_yaml) do
        {
          name: 'blah',
          'health-check-type': 'port',
          'readiness-health-check-type': 'http',
          'readiness-health-check-invocation-timeout': 2,
          'readiness-health-check-interval': 3,
          'readiness-health-check-http-endpoint': '/potato-potahto',
          disk_quota: '23M'
        }
      end

      it 'converts all keys to snake case' do
        expect(AppManifestMessage.underscore_keys(parsed_yaml)).to eq(
          {
            name: 'blah',
            health_check_type: 'port',
            readiness_health_check_type: 'http',
            readiness_health_check_invocation_timeout: 2,
            readiness_health_check_interval: 3,
            readiness_health_check_http_endpoint: '/potato-potahto',
            disk_quota: '23M'
          }
        )
      end

      context 'with processes' do
        let(:parsed_yaml) do
          {
            'name' => 'eugene', name: 'blah', processes: [
              { type: 'web', 'health-check-type': 'port', 'health-check-interval': 4, disk_quota: '23M' },
              { type: 'worker', 'health-check-type': 'port', disk_quota: '23M' },
              {
                type: 'song',
                'readiness-health-check-type': 'http',
                'readiness-health-check-invocation-timeout': 2,
                'readiness-health-check-interval': 3,
                'readiness-health-check-http-endpoint': '/potato-potahto',
                disk_quota: '23M'
              }

            ]
          }
        end

        it 'converts the processes keys into snake case for all processes' do
          expect(AppManifestMessage.underscore_keys(parsed_yaml)).to eq(
            { name: 'blah',
              processes: [
                { type: 'web',
                  health_check_type: 'port',
                  health_check_interval: 4,
                  disk_quota: '23M' },
                { type: 'worker',
                  health_check_type: 'port',
                  disk_quota: '23M' },
                { type: 'song',
                  readiness_health_check_type: 'http',
                  readiness_health_check_invocation_timeout: 2,
                  readiness_health_check_interval: 3,
                  readiness_health_check_http_endpoint: '/potato-potahto',
                  disk_quota: '23M' }
              ] }
          )
        end
      end

      context 'with environment variables' do
        let(:parsed_yaml) do
          {
            'name' => 'eugene', name: 'blah', env: { ':ENV_VAR' => 'hunter1' }, processes: [
              { type: 'web', env: { ':ENV_VAR' => 'hunter2' } },
              { type: 'worker', env: { ':ENV_VAR' => 'hunter3' } }
            ]
          }
        end

        it 'does NOT try to underscore them (so they do NOT get lowercased)' do
          expect(AppManifestMessage.underscore_keys(parsed_yaml)).to eq(
            { name: 'blah',
              env: { ':ENV_VAR' => 'hunter1' },
              processes: [
                { type: 'web',
                  env: { ':ENV_VAR' => 'hunter2' } },
                { type: 'worker',
                  env: { ':ENV_VAR' => 'hunter3' } }
              ] }
          )
        end
      end

      context 'with services' do
        let(:parsed_yaml) do
          {
            'name' => 'eugene', name: 'blah', services: ['hadoop'], processes: [
              { type: 'web', services: ['greenplumbdb'] },
              { type: 'worker', services: ['riak'] }
            ]
          }
        end

        it 'does NOT try to underscore the service names (they are strings not hashes)' do
          expect(AppManifestMessage.underscore_keys(parsed_yaml)).to eq(
            { name: 'blah',
              services: ['hadoop'],
              processes: [
                { type: 'web',
                  services: ['greenplumbdb'] },
                { type: 'worker',
                  services: ['riak'] }
              ] }
          )
        end
      end

      context 'when processes is incorrectly not an array' do
        context 'when nil' do
          let(:parsed_yaml) do
            { name: 'blah', processes: nil }
          end

          it 'does NOT raise an error' do
            expect(AppManifestMessage.underscore_keys(parsed_yaml)).to eq(
              { name: 'blah',
                processes: nil }
            )
          end
        end

        context 'when hash' do
          let(:parsed_yaml) do
            { name: 'blah', processes: { web: { 'woop-de': 'doop' } } }
          end

          it 'does NOT raise an error, but does not underscore anything' do
            expect(AppManifestMessage.underscore_keys(parsed_yaml)).to eq(
              { name: 'blah',
                processes: { web: { 'woop-de': 'doop' } } }
            )
          end
        end

        context 'when string' do
          let(:parsed_yaml) do
            { name: 'blah', processes: 'i am process' }
          end

          it 'does NOT raise an error' do
            expect(AppManifestMessage.underscore_keys(parsed_yaml)).to eq(
              { name: 'blah',
                processes: 'i am process' }
            )
          end
        end
      end
    end

    describe '#audit_hash' do
      let(:parsed_yaml) do
        {
          'disk_quota' => '1000GB',
          'memory' => '200GB',
          'instances' => 5,
          'env' => { 'foo' => 'bar' },
          'health-check-type' => 'port',
          'health-check-http-endpoint' => '/health',
          'routes' => [
            { 'route' => 'existing.example.com' },
            { 'route' => 'another.example.com' }
          ],
          'cnb-credentials' => {
            'example.org' => {
              'username' => 'foo',
              'password' => 'bar'
            }
          },
          'processes' => [{
            'type' => 'type',
            'command' => 'command',
            'health-check-type' => 'http',
            'health-check-http-endpoint' => '/healthier',
            'readiness-health-check-type' => 'port',
            'readiness-health-check-invocation-timeout' => 2,
            'readiness-health-check-http-endpoint' => '/potato-potahto'
          }]
        }
      end

      it 'returns the original requested yaml hash' do
        message = AppManifestMessage.create_from_yml(parsed_yaml)

        expected_hash = {
          'disk_quota' => '1000GB',
          'memory' => '200GB',
          'instances' => 5,
          'env' => '[PRIVATE DATA HIDDEN]',
          'health-check-type' => 'port',
          'health-check-http-endpoint' => '/health',
          'routes' => [
            { 'route' => 'existing.example.com' },
            { 'route' => 'another.example.com' }
          ],
          'cnb-credentials' => '[PRIVATE DATA HIDDEN]',
          'processes' => [{
            'type' => 'type',
            'command' => 'command',
            'health-check-type' => 'http',
            'health-check-http-endpoint' => '/healthier',
            'readiness-health-check-type' => 'port',
            'readiness-health-check-invocation-timeout' => 2,
            'readiness-health-check-http-endpoint' => '/potato-potahto'
          }]
        }

        expect(message.audit_hash).to eq(expected_hash)
      end

      context 'when "env" variables are present' do
        let(:parsed_yaml) do
          {
            'env' => { 'foo' => 'bar' }
          }
        end

        it 'redacts the environment variables' do
          message = AppManifestMessage.create_from_yml(parsed_yaml)

          expected_hash = {
            'env' => '[PRIVATE DATA HIDDEN]'
          }

          expect(message.audit_hash).to eq(expected_hash)
        end
      end

      context 'when "env" variables are not present' do
        let(:parsed_yaml) do
          {
            'memory' => '50T'
          }
        end

        it 'does NOT insert the redaction' do
          message = AppManifestMessage.create_from_yml(parsed_yaml)

          expected_hash = {
            'memory' => '50T'
          }

          expect(message.audit_hash).to eq(expected_hash)
        end
      end
    end

    describe '#manifest_process_scale_messages' do
      context 'from app-level attributes' do
        let(:parsed_yaml) { { 'name' => 'eugene', 'disk_quota' => '1000GB', 'memory' => '200GB', instances: 5 } }

        it 'returns a ManifestProcessScaleMessage containing mapped attributes' do
          message = AppManifestMessage.create_from_yml(parsed_yaml)

          expect(message).to be_valid
          expect(message.manifest_process_scale_messages.length).to eq(1)
          expect(message.manifest_process_scale_messages.first.instances).to eq(5)
          expect(message.manifest_process_scale_messages.first.memory).to eq(204_800)
          expect(message.manifest_process_scale_messages.first.disk_quota).to eq(1_024_000)
          expect(message.manifest_process_scale_messages.first.type).to eq('web')
        end

        context 'it handles bytes' do
          let(:parsed_yaml) { { 'name' => 'eugene', 'disk_quota' => '7340032B', 'memory' => '3145728B', instances: 8 } }

          it 'returns a ManifestProcessScaleMessage containing mapped attributes' do
            message = AppManifestMessage.create_from_yml(parsed_yaml)

            expect(message).to be_valid
            expect(message.manifest_process_scale_messages.length).to eq(1)
            expect(message.manifest_process_scale_messages.first.instances).to eq(8)
            expect(message.manifest_process_scale_messages.first.memory).to eq(3)
            expect(message.manifest_process_scale_messages.first.disk_quota).to eq(7)
          end
        end

        context 'it handles exactly 1MB' do
          let(:parsed_yaml) { { 'name' => 'eugene', 'disk_quota' => '1048576B', 'memory' => '1048576B', instances: 8 } }

          it 'returns a ManifestProcessScaleMessage containing mapped attributes' do
            message = AppManifestMessage.create_from_yml(parsed_yaml)

            expect(message).to be_valid
            expect(message.manifest_process_scale_messages.length).to eq(1)
            expect(message.manifest_process_scale_messages.first.instances).to eq(8)
            expect(message.manifest_process_scale_messages.first.memory).to eq(1)
            expect(message.manifest_process_scale_messages.first.disk_quota).to eq(1)
          end
        end

        context 'it complains about 1MB - 1' do
          let(:parsed_yaml) { { 'name' => 'eugene', 'disk_quota' => '1048575B', 'memory' => '1048575B', instances: 8 } }

          it 'returns a ManifestProcessScaleMessage containing mapped attributes' do
            message = AppManifestMessage.create_from_yml(parsed_yaml)

            expect(message).not_to be_valid
            expect(message.errors).to have(2).items
            expect(message.errors.full_messages).to contain_exactly('Process "web": Memory must be greater than 0MB', 'Process "web": Disk quota must be greater than 0MB')
          end
        end

        context 'when attributes are not requested in the manifest' do
          let(:parsed_yaml) { {} }

          it 'does not create any ManifestProcessScaleMessages' do
            message = AppManifestMessage.create_from_yml(parsed_yaml)

            expect(message.manifest_process_scale_messages.length).to eq(0)
          end
        end
      end

      context 'from nested process attributes' do
        let(:parsed_yaml) { { 'name' => 'eugene', 'processes' => [{ 'type' => 'web', 'disk_quota' => '1000GB', 'memory' => '200GB', instances: 5 }] } }

        it 'returns a ManifestProcessScaleMessage containing mapped attributes' do
          message = AppManifestMessage.create_from_yml(parsed_yaml)

          expect(message).to be_valid
          expect(message.manifest_process_scale_messages.length).to eq(1)
          expect(message.manifest_process_scale_messages.first.instances).to eq(5)
          expect(message.manifest_process_scale_messages.first.memory).to eq(204_800)
          expect(message.manifest_process_scale_messages.first.disk_quota).to eq(1_024_000)
          expect(message.manifest_process_scale_messages.first.type).to eq('web')
        end

        context 'it handles bytes' do
          let(:parsed_yaml) { { 'name' => 'eugene', 'processes' => [{ 'type' => 'web', 'disk_quota' => '7340032B', 'memory' => '3145728B', instances: 8 }] } }

          it 'returns a ManifestProcessScaleMessage containing mapped attributes' do
            message = AppManifestMessage.create_from_yml(parsed_yaml)

            expect(message).to be_valid
            expect(message.manifest_process_scale_messages.length).to eq(1)
            expect(message.manifest_process_scale_messages.first.instances).to eq(8)
            expect(message.manifest_process_scale_messages.first.memory).to eq(3)
            expect(message.manifest_process_scale_messages.first.disk_quota).to eq(7)
          end
        end

        context 'it handles exactly 1MB' do
          let(:parsed_yaml) { { 'name' => 'eugene', 'processes' => [{ 'type' => 'web', 'disk_quota' => '1048576B', 'memory' => '1048576B', instances: 8 }] } }

          it 'returns a ManifestProcessScaleMessage containing mapped attributes' do
            message = AppManifestMessage.create_from_yml(parsed_yaml)

            expect(message).to be_valid
            expect(message.manifest_process_scale_messages.length).to eq(1)
            expect(message.manifest_process_scale_messages.first.instances).to eq(8)
            expect(message.manifest_process_scale_messages.first.memory).to eq(1)
            expect(message.manifest_process_scale_messages.first.disk_quota).to eq(1)
          end
        end

        context 'it complains about 1MB - 1' do
          let(:parsed_yaml) { { 'name' => 'eugene', 'processes' => [{ 'type' => 'web', 'disk_quota' => '1048575B', 'memory' => '1048575B', instances: 8 }] } }

          it 'returns a ManifestProcessScaleMessage containing mapped attributes' do
            message = AppManifestMessage.create_from_yml(parsed_yaml)

            expect(message).not_to be_valid
            expect(message.errors).to have(2).items
            expect(message.errors.full_messages).to contain_exactly('Process "web": Memory must be greater than 0MB', 'Process "web": Disk quota must be greater than 0MB')
          end
        end

        context 'when processes and app-level process properties are specified' do
          context 'there is a web process type on the process level' do
            let(:parsed_yaml) do
              {
                'name' => 'eugene',
                'memory' => '5GB',
                'instances' => 1,
                'disk_quota' => '30GB',
                'processes' => [{ 'type' => 'web', 'disk_quota' => '1000GB', 'memory' => '200GB', instances: 5 }]
              }
            end

            it 'uses the values from the web process and ignores the app-level process properties' do
              message = AppManifestMessage.create_from_yml(parsed_yaml)

              expect(message).to be_valid
              expect(message.manifest_process_scale_messages.length).to eq(1)
              expect(message.manifest_process_scale_messages.first.instances).to eq(5)
              expect(message.manifest_process_scale_messages.first.memory).to eq(204_800)
              expect(message.manifest_process_scale_messages.first.disk_quota).to eq(1_024_000)
              expect(message.manifest_process_scale_messages.first.type).to eq('web')
            end
          end

          context 'there is not a web process type on the process level' do
            let(:parsed_yaml) do
              {
                'name' => 'eugene',
                'memory' => '5GB',
                'instances' => 1,
                'disk_quota' => '30GB',
                'processes' => [{ 'type' => 'worker', 'disk_quota' => '1000GB', 'memory' => '200GB', instances: 5 }]
              }
            end

            it 'uses the values from the app-level process for the web process' do
              message = AppManifestMessage.create_from_yml(parsed_yaml)

              expect(message).to be_valid
              expect(message.manifest_process_scale_messages.length).to eq(2)

              expect(message.manifest_process_scale_messages.first.instances).to eq(1)
              expect(message.manifest_process_scale_messages.first.memory).to eq(5120)
              expect(message.manifest_process_scale_messages.first.disk_quota).to eq(30_720)
              expect(message.manifest_process_scale_messages.first.type).to eq('web')

              expect(message.manifest_process_scale_messages.last.type).to eq('worker')
              expect(message.manifest_process_scale_messages.last.instances).to eq(5)
              expect(message.manifest_process_scale_messages.last.memory).to eq(204_800)
              expect(message.manifest_process_scale_messages.last.disk_quota).to eq(1_024_000)
            end
          end
        end
      end
    end

    describe '#manifest_process_update_messages' do
      context 'from app-level attributes' do
        let(:parsed_yaml) do
          {
            'name' => 'eugene',
            'command' => command,
            'health-check-type' => health_check_type,
            'health-check-http-endpoint' => health_check_http_endpoint,
            'health-check-invocation-timeout' => health_check_invocation_timeout,
            'health-check-interval' => health_check_interval,
            'readiness-health-check-type' => readiness_health_check_type,
            'readiness-health-check-invocation-timeout' => readiness_health_check_invocation_timeout,
            'readiness-health-check-interval' => readiness_health_check_interval,
            'readiness-health-check-http-endpoint' => readiness_health_check_http_endpoint,
            'timeout' => health_check_timeout
          }
        end

        let(:command) { 'new-command' }
        let(:health_check_type) { 'http' }
        let(:health_check_http_endpoint) { '/endpoint' }
        let(:health_check_invocation_timeout) { 1361 }
        let(:health_check_interval) { 1362 }
        let(:health_check_timeout) { 10 }
        let(:readiness_health_check_type) { 'http' }
        let(:readiness_health_check_invocation_timeout) { 2 }
        let(:readiness_health_check_interval) { 3 }
        let(:readiness_health_check_http_endpoint) { '/potato-potahto' }

        context 'when new properties are specified' do
          it 'sets the command and health check type fields in the message' do
            message = AppManifestMessage.create_from_yml(parsed_yaml)
            expect(message).to be_valid
            expect(message.manifest_process_update_messages.length).to eq(1)
            expect(message.manifest_process_update_messages.first.command).to eq('new-command')
            expect(message.manifest_process_update_messages.first.health_check_type).to eq('http')
            expect(message.manifest_process_update_messages.first.health_check_endpoint).to eq('/endpoint')
            expect(message.manifest_process_update_messages.first.health_check_timeout).to eq(10)
            expect(message.manifest_process_update_messages.first.health_check_invocation_timeout).to eq(1361)
            expect(message.manifest_process_update_messages.first.health_check_interval).to eq(1362)
            expect(message.manifest_process_update_messages.first.readiness_health_check_type).to eq('http')
            expect(message.manifest_process_update_messages.first.readiness_health_check_invocation_timeout).to eq(2)
            expect(message.manifest_process_update_messages.first.readiness_health_check_interval).to eq(3)
            expect(message.manifest_process_update_messages.first.readiness_health_check_http_endpoint).to eq('/potato-potahto')
          end
        end

        context 'readiness health checks' do
          context 'only readiness checks' do
            let(:parsed_yaml) do
              {
                'name' => 'eugene',
                'readiness-health-check-type': 'http',
                'readiness-health-check-invocation-timeout': 2,
                'readiness-health-check-http-endpoint': '/potato-potahto'
              }
            end

            it 'is converted to process' do
              message = AppManifestMessage.create_from_yml(parsed_yaml)
              expect(message).to be_valid
              expect(message.manifest_process_update_messages.length).to eq(1)
              expect(message.manifest_process_update_messages.first.readiness_health_check_type).to eq('http')
              expect(message.manifest_process_update_messages.first.readiness_health_check_invocation_timeout).to eq(2)
              expect(message.manifest_process_update_messages.first.readiness_health_check_http_endpoint).to eq('/potato-potahto')
            end
          end
        end

        context 'health checks' do
          context 'deprecated health check type none' do
            let(:parsed_yaml) { { 'name' => 'eugene', 'health-check-type': 'none' } }

            it 'is converted to process' do
              message = AppManifestMessage.create_from_yml(parsed_yaml)
              expect(message).to be_valid
              expect(message.manifest_process_update_messages.length).to eq(1)
              expect(message.manifest_process_update_messages.first.health_check_type).to eq('process')
            end
          end

          context 'health check timeout without other health check parameters' do
            let(:health_check_timeout) { 10 }
            let(:parsed_yaml) { { name: 'eugene', timeout: health_check_timeout } }

            it 'sets the health check timeout in the message' do
              message = AppManifestMessage.create_from_yml(parsed_yaml)
              expect(message).to be_valid
              expect(message.manifest_process_update_messages.length).to eq(1)
              expect(message.manifest_process_update_messages.first.health_check_timeout).to eq(10)
            end
          end

          context 'health check invocation timeout without other health check parameters' do
            let(:health_check_invocation_timeout) { 2493 }
            let(:parsed_yaml) { { name: 'eugene', health_check_invocation_timeout: health_check_invocation_timeout } }

            it 'sets the health check timeout in the message' do
              message = AppManifestMessage.create_from_yml(parsed_yaml)
              expect(message).to be_valid
              expect(message.manifest_process_update_messages.length).to eq(1)
              expect(message.manifest_process_update_messages.first.health_check_invocation_timeout).to eq(2493)
            end
          end

          context 'when health check type is port' do
            let(:parsed_yaml) { { 'name' => 'eugene', 'health-check-type' => 'port' } }

            it 'does not set the endpoint' do
              message = AppManifestMessage.create_from_yml(parsed_yaml)
              expect(message).to be_valid
              expect(message.manifest_process_update_messages.length).to eq(1)
              expect(message.manifest_process_update_messages.first.health_check_type).to eq('port')
              expect(message.manifest_process_update_messages.first.health_check_endpoint).to be_nil
            end

            it 'applies the health check invocation timeout if supplied' do
              parsed_yaml['health_check_invocation_timeout'] = 2493

              message = AppManifestMessage.create_from_yml(parsed_yaml)
              expect(message).to be_valid
              expect(message.manifest_process_update_messages.length).to eq(1)
              expect(message.manifest_process_update_messages.first.health_check_invocation_timeout).to eq(2493)
            end
          end

          context 'when the health check endpoint is not specified' do
            let(:parsed_yaml) { { 'name' => 'eugene', 'health-check-type' => 'http' } }

            it 'returns nil as the endpoint' do
              message = AppManifestMessage.create_from_yml(parsed_yaml)
              expect(message).to be_valid
              expect(message.manifest_process_update_messages.first.health_check_endpoint).to be_nil
            end
          end

          context 'when the health check type is nonsense' do
            let(:parsed_yaml) { { 'name' => 'eugene', 'health-check-type' => 'nonsense' } }

            it 'returns the error' do
              message = AppManifestMessage.create_from_yml(parsed_yaml)
              expect(message).not_to be_valid
              expect(message.errors.full_messages).to include(
                'Process "web": Health check type must be "port", "process", or "http"'
              )
            end
          end
        end

        context 'command' do
          context 'when a string command of value "null" is specified' do
            let(:command) { 'null' }

            it 'does not set the command field in the process update message' do
              message = AppManifestMessage.create_from_yml(parsed_yaml)
              expect(message).to be_valid
              expect(message.manifest_process_update_messages.length).to eq(1)
              expect(message.manifest_process_update_messages.first.command).to eq('null')
            end
          end

          # This happens when users specify `command: ` with no value in the manifest.
          context 'when a nil command (value nil) is specified' do
            let(:command) { nil }

            it 'sets the field as null in the process update message' do
              message = AppManifestMessage.create_from_yml(parsed_yaml)
              expect(message).to be_valid
              expect(message.manifest_process_update_messages.length).to eq(1)
              expect(message.manifest_process_update_messages.first.command).to eq('null')
            end
          end

          context 'when a default command is specified' do
            let(:command) { 'default' }

            it 'does not set the command field in the process update message' do
              message = AppManifestMessage.create_from_yml(parsed_yaml)
              expect(message).to be_valid
              expect(message.manifest_process_update_messages.length).to eq(1)
              expect(message.manifest_process_update_messages.first.command).to eq('default')
            end
          end
        end

        context 'when no parameters are specified' do
          let(:parsed_yaml) do
            { 'name' => 'eugene' }
          end

          it 'does not set a command or health_check_type field' do
            message = AppManifestMessage.create_from_yml(parsed_yaml)
            expect(message).to be_valid
            expect(message.manifest_process_update_messages.length).to eq(0)
          end
        end
      end

      context 'from nested process attributes' do
        let(:parsed_yaml) do
          {
            'name' => 'eugene',
            'processes' => [{
              'type' => type,
              'command' => command,
              'health-check-type' => health_check_type,
              'health-check-http-endpoint' => health_check_http_endpoint,
              'timeout' => health_check_timeout
            }]
          }
        end

        let(:type) { 'web' }
        let(:command) { 'new-command' }
        let(:health_check_type) { 'http' }
        let(:health_check_http_endpoint) { '/endpoint' }
        let(:health_check_timeout) { 10 }

        context 'when new properties are specified' do
          it 'sets the command and health check type fields in the message' do
            message = AppManifestMessage.create_from_yml(parsed_yaml)
            expect(message).to be_valid
            expect(message.manifest_process_update_messages.length).to eq(1)
            expect(message.manifest_process_update_messages.first.command).to eq('new-command')
            expect(message.manifest_process_update_messages.first.health_check_type).to eq('http')
            expect(message.manifest_process_update_messages.first.health_check_endpoint).to eq('/endpoint')
            expect(message.manifest_process_update_messages.first.health_check_timeout).to eq(10)
          end
        end

        context 'health checks' do
          context 'deprecated health check type none' do
            let(:parsed_yaml) { { name: 'eugene', 'health-check-type': 'none' } }

            it 'is converted to process' do
              message = AppManifestMessage.create_from_yml(parsed_yaml)
              expect(message).to be_valid
              expect(message.manifest_process_update_messages.length).to eq(1)
              expect(message.manifest_process_update_messages.first.health_check_type).to eq('process')
            end
          end

          context 'health check timeout without other health check parameters' do
            let(:health_check_timeout) { 10 }
            let(:parsed_yaml) { { name: 'eugene', timeout: health_check_timeout } }

            it 'sets the health check timeout in the message' do
              message = AppManifestMessage.create_from_yml(parsed_yaml)
              expect(message).to be_valid
              expect(message.manifest_process_update_messages.length).to eq(1)
              expect(message.manifest_process_update_messages.first.health_check_timeout).to eq(10)
            end
          end

          context 'when health check type is not http and endpoint is not specified' do
            let(:parsed_yaml) { { 'name' => 'eugene', 'health-check-type' => 'port' } }

            it 'does not default endpoint to "/"' do
              message = AppManifestMessage.create_from_yml(parsed_yaml)
              expect(message).to be_valid
              expect(message.manifest_process_update_messages.length).to eq(1)
              expect(message.manifest_process_update_messages.first.health_check_type).to eq('port')
              expect(message.manifest_process_update_messages.first.health_check_endpoint).to be_nil
            end
          end
        end

        context 'command' do
          context 'when command is not requested' do
            let(:parsed_yaml) { { 'name' => 'eugene', 'processes' => [{ 'type' => 'web' }] } }

            it 'does not set the command field in the process update message' do
              message = AppManifestMessage.create_from_yml(parsed_yaml)
              expect(message).to be_valid
              expect(message.manifest_process_update_messages.length).to eq(1)
              expect(message.manifest_process_update_messages.first.requested?(:command)).to be false
            end
          end

          context 'when a string command of value "null" is specified' do
            let(:command) { 'null' }

            it 'does not set the command field in the process update message' do
              message = AppManifestMessage.create_from_yml(parsed_yaml)
              expect(message).to be_valid
              expect(message.manifest_process_update_messages.length).to eq(1)
              expect(message.manifest_process_update_messages.first.command).to eq('null')
            end
          end

          # This happens when users specify `command: ` with no value in the manifest.
          context 'when a nil command (value nil) is specified' do
            let(:command) { nil }

            it 'sets the field as null in the process update message' do
              message = AppManifestMessage.create_from_yml(parsed_yaml)
              expect(message).to be_valid
              expect(message.manifest_process_update_messages.length).to eq(1)
              expect(message.manifest_process_update_messages.first.command).to eq('null')
            end
          end

          context 'when a default command is specified' do
            let(:command) { 'default' }

            it 'does not set the command field in the process update message' do
              message = AppManifestMessage.create_from_yml(parsed_yaml)
              expect(message).to be_valid
              expect(message.manifest_process_update_messages.length).to eq(1)
              expect(message.manifest_process_update_messages.first.command).to eq('default')
            end
          end

          context 'when processes and app-level process properties are specified' do
            context 'there is a web process type on the process level' do
              let(:parsed_yaml) do
                {
                  'name' => 'eugene',
                  'command' => 'ignoreme',
                  'health_check_http_endpoint' => '/not-here',
                  'health_check_type' => 'http',
                  'timeout' => 5,
                  'processes' => [{ 'type' => 'web', 'command' => 'thisone', 'health_check_type' => 'port', 'timeout' => 10 }]
                }
              end

              it 'uses the values from the web process and ignores the app-level process properties' do
                message = AppManifestMessage.create_from_yml(parsed_yaml)

                expect(message).to be_valid
                expect(message.manifest_process_update_messages.length).to eq(1)
                expect(message.manifest_process_update_messages.first.type).to eq('web')
                expect(message.manifest_process_update_messages.first.command).to eq('thisone')
                expect(message.manifest_process_update_messages.first.health_check_type).to eq('port')
                expect(message.manifest_process_update_messages.first.health_check_http_endpoint).to be_falsey
                expect(message.manifest_process_update_messages.first.timeout).to eq(10)
              end
            end

            context 'there is not a web process type on the process level' do
              let(:parsed_yaml) do
                {
                  'name' => 'eugene',
                  'command' => 'ignoreme',
                  'health_check_http_endpoint' => '/not-here',
                  'health_check_type' => 'http',
                  'timeout' => 5,
                  'processes' => [{ 'type' => 'worker', 'command' => 'thisone', 'health_check_type' => 'port', 'timeout' => 10 }]
                }
              end

              it 'uses the values from the app-level process for the web process' do
                message = AppManifestMessage.create_from_yml(parsed_yaml)

                expect(message).to be_valid
                expect(message.manifest_process_update_messages.length).to eq(2)

                expect(message.manifest_process_update_messages.first.type).to eq('web')
                expect(message.manifest_process_update_messages.first.command).to eq('ignoreme')
                expect(message.manifest_process_update_messages.first.health_check_type).to eq('http')
                expect(message.manifest_process_update_messages.first.health_check_http_endpoint).to eq('/not-here')
                expect(message.manifest_process_update_messages.first.timeout).to eq(5)

                expect(message.manifest_process_update_messages.last.type).to eq('worker')
                expect(message.manifest_process_update_messages.last.command).to eq('thisone')
                expect(message.manifest_process_update_messages.last.health_check_type).to eq('port')
                expect(message.manifest_process_update_messages.last.health_check_http_endpoint).to be_falsey
                expect(message.manifest_process_update_messages.last.timeout).to eq(10)
              end
            end
          end
        end
      end
    end

    describe '#sidecar_create_messages' do
      context 'when new sidecars are specified' do
        let(:parsed_yaml) do
          {
            'name' => 'dora',
            'sidecars' => [{
              'name' => 'my_sidecar',
              'command' => 'rackup sidecar',
              'process_types' => ['web']
            },
                           {
                             'name' => 'my_second_sidecar',
                             'command' => 'rackup sidecar',
                             'process_types' => ['web']
                           }]
          }
        end

        it 'returns sidecar update messages' do
          message = AppManifestMessage.create_from_yml(parsed_yaml)
          expect(message).to be_valid
          expect(message.sidecar_create_messages.length).to eq(2)
          expect(message.sidecar_create_messages.map(&:name)).to eq(%w[my_sidecar my_second_sidecar])
        end
      end

      context 'when no sidecars are specified' do
        let(:parsed_yaml) do
          {
            'name' => 'dora'
          }
        end

        it 'returns an empty array' do
          message = AppManifestMessage.create_from_yml(parsed_yaml)
          expect(message).to be_valid
          expect(message.sidecar_create_messages).to eq([])
        end
      end
    end

    describe '#app_update_message' do
      let(:buildpack) { VCAP::CloudController::Buildpack.make }
      let(:stack) { VCAP::CloudController::Stack.make }
      let(:parsed_yaml) { { 'buildpack' => buildpack.name, 'stack' => stack.name } }

      context 'when neither buildpack or docker is specified' do
        context 'when attributes are not requested in the manifest' do
          context 'when no lifecycle data is requested in the manifest' do
            let(:parsed_yaml) { {} }

            it 'does not forward missing attributes to the AppUpdateMessage' do
              message = AppManifestMessage.create_from_yml(parsed_yaml)
              expect(message.app_update_message.requested?(:lifecycle)).to be false
            end
          end

          context 'when stack is not requested in the manifest but buildpack is requested' do
            let(:parsed_yaml) { { 'buildpack' => buildpack.name } }

            it 'does not forward missing attributes to the AppUpdateMessage' do
              message = AppManifestMessage.create_from_yml(parsed_yaml)

              expect(message.app_update_message.requested?(:lifecycle)).to be true
              expect(message.app_update_message.buildpack_data.requested?(:buildpacks)).to be true
              expect(message.app_update_message.buildpack_data.requested?(:stack)).to be false
            end
          end

          context 'when buildpack is not requested in the manifest but stack is requested' do
            let(:parsed_yaml) { { 'stack' => stack.name } }

            it 'does not forward missing attributes to the AppUpdateMessage' do
              message = AppManifestMessage.create_from_yml(parsed_yaml)

              expect(message.app_update_message.requested?(:lifecycle)).to be true
              expect(message.app_update_message.buildpack_data.requested?(:buildpacks)).to be false
              expect(message.app_update_message.buildpack_data.requested?(:stack)).to be true
            end
          end
        end
      end

      context 'when buildpacks are specified' do
        it 'returns an AppUpdateMessage containing mapped attributes' do
          message = AppManifestMessage.create_from_yml(parsed_yaml)

          expect(message.app_update_message.buildpack_data.buildpacks).to include(buildpack.name)
          expect(message.app_update_message.buildpack_data.stack).to eq(stack.name)
        end

        context 'when it specifies a "default" buildpack' do
          let(:parsed_yaml) { { buildpack: 'default' } }

          it 'updates the buildpack_data to be an empty array' do
            message = AppManifestMessage.create_from_yml(parsed_yaml)
            expect(message.app_update_message.buildpack_data.buildpacks).to be_empty
          end
        end

        context 'when it specifies a null buildpack' do
          let(:parsed_yaml) { { buildpack: nil } }

          it 'updates the buildpack_data to be an empty array' do
            message = AppManifestMessage.create_from_yml(parsed_yaml)
            expect(message.app_update_message.buildpack_data.buildpacks).to be_empty
          end
        end

        context 'when it specifies a "null" buildpack' do
          let(:parsed_yaml) { { buildpack: 'null' } }

          it 'updates the buildpack_data to be an empty array' do
            message = AppManifestMessage.create_from_yml(parsed_yaml)
            expect(message.app_update_message.buildpack_data.buildpacks).to be_empty
          end
        end
      end

      context 'when docker is specified' do
        let(:parsed_yaml) { { docker: { image: 'my/docker' } } }

        it 'returns an AppUpdateMessage containing mapped attributes' do
          message = AppManifestMessage.create_from_yml(parsed_yaml)

          expect(message.app_update_message.lifecycle_type).to eq(Lifecycles::DOCKER)
        end
      end

      context 'when cnb is specified' do
        let(:parsed_yaml) { { name: 'cnb', lifecycle: 'cnb', buildpacks: %w[nodejs java], stack: stack.name } }

        context 'when cnb is enabled' do
          before do
            FeatureFlag.make(name: 'diego_cnb', enabled: true, error_message: nil)
          end

          it 'is valid' do
            message = AppManifestMessage.create_from_yml(parsed_yaml)

            expect(message).to be_valid
            expect(message.app_update_message.lifecycle_type).to eq(Lifecycles::CNB)
            expect(message.app_update_message.buildpack_data.buildpacks).to eq(%w[nodejs java])
            expect(message.app_update_message.buildpack_data.stack).to eq(stack.name)
            expect(message.app_update_message.buildpack_data.credentials).to be_nil
          end

          context 'when cnb_credentials key is specified' do
            let(:parsed_yaml) { { name: 'cnb', lifecycle: 'cnb', buildpacks: %w[nodejs java], stack: stack.name, cnb_credentials: { registry: { username: 'password' } } } }

            it 'adds credentials to the lifecycle_data' do
              message = AppManifestMessage.create_from_yml(parsed_yaml)

              expect(message).to be_valid
              expect(message.app_update_message.lifecycle_type).to eq(Lifecycles::CNB)
              expect(message.app_update_message.buildpack_data.buildpacks).to eq(%w[nodejs java])
              expect(message.app_update_message.buildpack_data.stack).to eq(stack.name)
              expect(message.app_update_message.buildpack_data.credentials).to eq({ registry: { username: 'password' } })
            end
          end
        end

        context 'when buildpack is the default_app_lifecycle but lifecycle is not set' do
          before do
            TestConfig.override(default_app_lifecycle: 'buildpack')
          end

          let(:parsed_yaml) { { name: 'cnb', buildpacks: %w[nodejs java], stack: stack.name } }

          it 'sets the app lifecycle to nil' do
            message = AppManifestMessage.create_from_yml(parsed_yaml)

            expect(message).to be_valid
            expect(message.app_update_message.lifecycle_type).to be_nil
            expect(message.app_update_message.buildpack_data.buildpacks).to eq(%w[nodejs java])
            expect(message.app_update_message.buildpack_data.stack).to eq(stack.name)
            expect(message.app_update_message.buildpack_data.credentials).to be_nil
          end
        end

        context 'when cnb is the default_app_lifecycle but lifecycle is not set' do
          before do
            TestConfig.override(default_app_lifecycle: 'cnb')
          end

          let(:parsed_yaml) { { name: 'cnb', buildpacks: %w[nodejs java], stack: stack.name } }

          it 'sets the app lifecycle to cnb' do
            message = AppManifestMessage.create_from_yml(parsed_yaml)

            expect(message).to be_valid
            expect(message.app_update_message.lifecycle_type).to be_nil
            expect(message.app_update_message.buildpack_data.buildpacks).to eq(%w[nodejs java])
            expect(message.app_update_message.buildpack_data.stack).to eq(stack.name)
            expect(message.app_update_message.buildpack_data.credentials).to be_nil
          end
        end

        context 'when cnb is disabled' do
          before do
            FeatureFlag.make(name: 'diego_cnb', enabled: false, error_message: 'I am a banana')
          end

          it 'is not valid' do
            message = AppManifestMessage.create_from_yml(parsed_yaml)

            expect(message).not_to be_valid
            expect(message.errors).to have(1).items
            expect(message.errors.full_messages).to include('Feature Disabled: I am a banana')
          end
        end
      end
    end

    describe '#app_update_environment_variables_message' do
      let(:parsed_yaml) { { 'name' => 'eugene', 'env' => { 'foo' => 'bar', 'baz' => 4.44444444444, 'qux' => false } } }

      it 'returns a UpdateEnvironmentVariablesMessage containing the env vars' do
        message = AppManifestMessage.create_from_yml(parsed_yaml)
        expect(message).to be_valid
        expect(message.app_update_environment_variables_message.var).
          to eq({ foo: 'bar', baz: '4.44444444444', qux: 'false' })
      end
    end

    describe '#manifest_routes_update_message' do
      context 'when no-route value is not a boolean' do
        let(:parsed_yaml) do
          {
            'name' => 'eugene',
            'no-route' => 3,
            'routes' =>
            [
              { 'route' => 'existing.example.com' }
            ]
          }
        end

        it 'is invalid' do
          message = AppManifestMessage.create_from_yml(parsed_yaml)
          expect(message).not_to be_valid
          expect(message.errors[:base]).to include('No-route must be a boolean')
        end
      end

      context 'when no routes are specified' do
        let(:parsed_yaml) do
          { 'name' => 'eugene' }
        end

        it 'does not set the routes in the message' do
          message = AppManifestMessage.create_from_yml(parsed_yaml)
          expect(message).to be_valid
          expect(message.manifest_routes_update_message).not_to be_requested(:routes)
        end
      end
    end
  end
end
