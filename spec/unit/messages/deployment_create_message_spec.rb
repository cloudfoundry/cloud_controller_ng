require 'lightweight_spec_helper'
require 'messages/deployment_create_message'
module VCAP::CloudController
  RSpec.describe DeploymentCreateMessage do
    let(:body) do
      {
        'strategy' => 'rolling',
        'relationships' => {
          'app' => {
            'data' => {
              'guid' => '123'
            }
          }
        }
      }
    end

    describe 'validations' do
      describe 'strategy' do
        it 'can be rolling' do
          body['strategy'] = 'rolling'
          message = DeploymentCreateMessage.new(body)
          expect(message).to be_valid
        end

        it 'can be canary' do
          body['strategy'] = 'canary'
          message = DeploymentCreateMessage.new(body)
          expect(message).to be_valid
        end

        it 'can be recreate' do
          body['strategy'] = 'recreate'
          message = DeploymentCreateMessage.new(body)
          expect(message).to be_valid
        end

        it 'is valid with nil strategy' do
          body['strategy'] = nil
          message = DeploymentCreateMessage.new(body)
          expect(message).to be_valid
        end

        it 'is not a valid strategy' do
          body['strategy'] = 'potato'
          message = DeploymentCreateMessage.new(body)
          expect(message).not_to be_valid
          expect(message.errors.full_messages).to include("Strategy 'potato' is not a supported deployment strategy")
        end
      end

      describe 'options' do
        context 'not set' do
          before do
            body['options'] = nil
          end

          it 'succeeds' do
            message = DeploymentCreateMessage.new(body)
            expect(message).to be_valid
          end
        end

        context 'set to a non-hash' do
          before do
            body['options'] = 'foo'
          end

          it 'is not valid' do
            message = DeploymentCreateMessage.new(body)
            expect(message).not_to be_valid
          end
        end

        context 'when set to hash' do
          before do
            body['options'] = {}
          end

          it 'succeeds' do
            message = DeploymentCreateMessage.new(body)
            expect(message).to be_valid
          end
        end
      end

      describe 'max_in_flight' do
        context 'when set to a non-integer' do
          before do
            body['options'] = { max_in_flight: 'two' }
          end

          it 'is not valid' do
            message = DeploymentCreateMessage.new(body)
            expect(message).not_to be_valid
            expect(message.errors.full_messages).to include('Max in flight must be an integer greater than 0')
          end
        end

        context 'when set to a negative integer' do
          before do
            body['options'] = { max_in_flight: -2 }
          end

          it 'is not valid' do
            message = DeploymentCreateMessage.new(body)
            expect(message).not_to be_valid
            expect(message.errors.full_messages).to include('Max in flight must be an integer greater than 0')
          end
        end

        context 'when set to zero' do
          before do
            body['options'] = { max_in_flight: 0 }
          end

          it 'is not valid' do
            message = DeploymentCreateMessage.new(body)
            expect(message).not_to be_valid
            expect(message.errors.full_messages).to include('Max in flight must be an integer greater than 0')
          end
        end

        context 'when set to positive integer' do
          before do
            body['options'] = { max_in_flight: 2 }
          end

          it 'succeeds' do
            message = DeploymentCreateMessage.new(body)
            expect(message).to be_valid
          end
        end

        context 'when set with recreate strategy' do
          before do
            body['options'] = { max_in_flight: 2 }
          end

          it 'is not valid' do
            body['strategy'] = 'recreate'
            message = DeploymentCreateMessage.new(body)
            expect(message).not_to be_valid
            expect(message.errors.full_messages).to include('Options max in flight is not a supported option for recreate deployment strategy')
          end
        end
      end

      describe 'web_instances' do
        context 'when set to a non-integer' do
          before do
            body['options'] = { web_instances: 'two' }
          end

          it 'is not valid' do
            message = DeploymentCreateMessage.new(body)
            expect(message).not_to be_valid
            expect(message.errors.full_messages).to include('Web instances is not a number')
          end
        end

        context 'when set to a negative integer' do
          before do
            body['options'] = { web_instances: -2 }
          end

          it 'is not valid' do
            message = DeploymentCreateMessage.new(body)
            expect(message).not_to be_valid
            expect(message.errors.full_messages).to include('Web instances must be greater than or equal to 0')
          end
        end

        context 'when set to zero' do
          before do
            body['options'] = { web_instances: 0 }
          end

          it 'is valid' do
            message = DeploymentCreateMessage.new(body)
            expect(message).to be_valid
          end
        end

        context 'when set to positive integer' do
          before do
            body['options'] = { web_instances: 2 }
          end

          it 'succeeds' do
            message = DeploymentCreateMessage.new(body)
            expect(message).to be_valid
          end
        end
      end

      describe 'memory_in_mb' do
        context 'when set to a non-integer' do
          before do
            body['options'] = { memory_in_mb: 'two' }
          end

          it 'is not valid' do
            message = DeploymentCreateMessage.new(body)
            expect(message).not_to be_valid
            expect(message.errors.full_messages).to include('Memory in mb is not a number')
          end
        end

        context 'when set to a negative integer' do
          before do
            body['options'] = { memory_in_mb: -2 }
          end

          it 'is not valid' do
            message = DeploymentCreateMessage.new(body)
            expect(message).not_to be_valid
            expect(message.errors.full_messages).to include('Memory in mb must be greater than 0')
          end
        end

        context 'when set to zero' do
          before do
            body['options'] = { memory_in_mb: 0 }
          end

          it 'is not valid' do
            message = DeploymentCreateMessage.new(body)
            expect(message).not_to be_valid
            expect(message.errors.full_messages).to include('Memory in mb must be greater than 0')
          end
        end

        context 'when set to positive integer' do
          before do
            body['options'] = { memory_in_mb: 2 }
          end

          it 'succeeds' do
            message = DeploymentCreateMessage.new(body)
            expect(message).to be_valid
          end
        end
      end

      describe 'disk_in_mb' do
        context 'when set to a non-integer' do
          before do
            body['options'] = { disk_in_mb: 'two' }
          end

          it 'is not valid' do
            message = DeploymentCreateMessage.new(body)
            expect(message).not_to be_valid
            expect(message.errors.full_messages).to include('Disk in mb is not a number')
          end
        end

        context 'when set to a negative integer' do
          before do
            body['options'] = { disk_in_mb: -2 }
          end

          it 'is not valid' do
            message = DeploymentCreateMessage.new(body)
            expect(message).not_to be_valid
            expect(message.errors.full_messages).to include('Disk in mb must be greater than 0')
          end
        end

        context 'when set to zero' do
          before do
            body['options'] = { disk_in_mb: 0 }
          end

          it 'is not valid' do
            message = DeploymentCreateMessage.new(body)
            expect(message).not_to be_valid
            expect(message.errors.full_messages).to include('Disk in mb must be greater than 0')
          end
        end

        context 'when set to positive integer' do
          before do
            body['options'] = { disk_in_mb: 2 }
          end

          it 'succeeds' do
            message = DeploymentCreateMessage.new(body)
            expect(message).to be_valid
          end
        end
      end

      describe 'log_rate_limit_in_bytes_per_second' do
        context 'when set to a non-integer' do
          before do
            body['options'] = { log_rate_limit_in_bytes_per_second: 'two' }
          end

          it 'is not valid' do
            message = DeploymentCreateMessage.new(body)
            expect(message).not_to be_valid
            expect(message.errors.full_messages).to include('Log rate limit in bytes per second is not a number')
          end
        end

        context 'when set to a negative integer below -1' do
          before do
            body['options'] = { log_rate_limit_in_bytes_per_second: -2 }
          end

          it 'is not valid' do
            message = DeploymentCreateMessage.new(body)
            expect(message).not_to be_valid
            expect(message.errors.full_messages).to include('Log rate limit in bytes per second must be greater than or equal to -1')
          end
        end

        context 'when set negative 1' do
          before do
            body['options'] = { log_rate_limit_in_bytes_per_second: -1 }
          end

          it 'is not valid' do
            message = DeploymentCreateMessage.new(body)
            expect(message).to be_valid
          end
        end

        context 'when set to zero' do
          before do
            body['options'] = { log_rate_limit_in_bytes_per_second: 0 }
          end

          it 'is not valid' do
            message = DeploymentCreateMessage.new(body)
            expect(message).to be_valid
          end
        end

        context 'when set to positive integer' do
          before do
            body['options'] = { log_rate_limit_in_bytes_per_second: 2 }
          end

          it 'succeeds' do
            message = DeploymentCreateMessage.new(body)
            expect(message).to be_valid
          end
        end
      end

      describe 'canary options' do
        before do
          body['strategy'] = 'canary'
        end

        it 'is valid when options is nil' do
          body['options'] = { 'canary' => nil }
          message = DeploymentCreateMessage.new(body)
          expect(message).to be_valid
        end

        it 'is valid when options a hash' do
          body['options'] = { canary: {} }
          message = DeploymentCreateMessage.new(body)
          expect(message).to be_valid
        end

        it 'errors when options is not a hash' do
          body['options'] = { canary: 'test' }
          message = DeploymentCreateMessage.new(body)
          expect(message).not_to be_valid
          expect(message.errors[:'options.canary']).to include('must be an object')
        end

        it 'errors when strategy is not set' do
          body['options'] = { canary: {} }
          body['strategy'] = nil
          message = DeploymentCreateMessage.new(body)
          expect(message).not_to be_valid
          expect(message.errors[:'options.canary']).to include('are only valid for Canary deployments')
        end

        it 'errors when strategy is set to rolling' do
          body['options'] = { canary: {} }
          body['strategy'] = 'rolling'
          message = DeploymentCreateMessage.new(body)
          expect(message).not_to be_valid
          expect(message.errors[:'options.canary']).to include('are only valid for Canary deployments')
        end

        it 'errors when strategy is set to recreate' do
          body['options'] = { canary: {} }
          body['strategy'] = 'recreate'
          message = DeploymentCreateMessage.new(body)
          expect(message).not_to be_valid
          expect(message.errors[:'options.canary']).to include('are only valid for Canary deployments')
        end

        it 'errors when there is an unknown option' do
          body['options'] = { foo: 'bar', baz: 'boo' }
          message = DeploymentCreateMessage.new(body)
          expect(message).not_to be_valid
          expect(message.errors[:options]).to include('has unsupported key(s): foo, baz')
        end

        context 'steps' do
          it 'errors when is not an array' do
            body['options'] = { canary: { steps: 'foo' } }
            message = DeploymentCreateMessage.new(body)
            expect(message).not_to be_valid
            expect(message.errors[:'options.canary.steps']).to include('must be an array of objects')
          end

          it 'is valid when is an empty array' do
            body['options'] = { canary: { steps: [] } }
            message = DeploymentCreateMessage.new(body)
            expect(message).to be_valid
          end

          it 'is valid when is nil' do
            body['options'] = { canary: { steps: nil } }
            message = DeploymentCreateMessage.new(body)
            expect(message).to be_valid
          end

          it 'errors if not an array of objects' do
            body['options'] = { canary: { steps: [{ instance_weight: 1 }, 'foo'] } }
            message = DeploymentCreateMessage.new(body)
            expect(message).not_to be_valid
            expect(message.errors[:'options.canary.steps']).to include('must be an array of objects')
          end

          it 'errors if steps have an unsupported key' do
            body['options'] = { canary: { steps: [{ instance_weight: 1 }, { instance_weight: 1, foo: 'bar', baz: 1 }, { baz: 1 }] } }
            message = DeploymentCreateMessage.new(body)
            expect(message).not_to be_valid
            expect(message.errors[:'options.canary.steps']).to include('has unsupported key(s): foo, baz')
            expect(message.errors[:'options.canary.steps']).to include('has unsupported key(s): baz')
          end

          context 'instance_weights' do
            it 'is valid if instance_weights are Integers between 1-100 in ascending order' do
              body['options'] = { canary: { steps: [{ instance_weight: 1 }, { instance_weight: 2 }, { instance_weight: 50 }, { instance_weight: 99 }, { instance_weight: 100 }] } }
              message = DeploymentCreateMessage.new(body)
              expect(message).to be_valid
            end

            it 'is valid if there are duplicate instance_weights' do
              body['options'] = { canary: { steps: [{ instance_weight: 10 }, { instance_weight: 10 }, { instance_weight: 50 }, { instance_weight: 50 }] } }
              message = DeploymentCreateMessage.new(body)
              expect(message).to be_valid
            end

            it 'errors if steps are missing instance_weight' do
              body['options'] = { canary: { steps: [{ instance_weight: 1 }, { foo: 'bar' }] } }
              message = DeploymentCreateMessage.new(body)
              expect(message).not_to be_valid
              expect(message.errors[:'options.canary.steps']).to include('missing key: "instance_weight"')
            end

            it 'errors if steps are missing instance_weight with empty hash' do
              body['options'] = { canary: { steps: [{ instance_weight: 1 }, {}] } }
              message = DeploymentCreateMessage.new(body)
              expect(message).not_to be_valid
              expect(message.errors[:'options.canary.steps']).to include('missing key: "instance_weight"')
            end

            it 'errors if any instance_weight is not an Integer' do
              body['options'] = { canary: { steps: [{ instance_weight: 'foo' }] } }
              message = DeploymentCreateMessage.new(body)
              expect(message).not_to be_valid
              expect(message.errors[:'options.canary.steps.instance_weight']).to include('must be an Integer between 1-100 (inclusive)')
            end

            it 'errors if any instance_weight is equal to 0' do
              body['options'] = { canary: { steps: [{ instance_weight: 0 }, { instance_weight: 50 }] } }
              message = DeploymentCreateMessage.new(body)
              expect(message).not_to be_valid
              expect(message.errors[:'options.canary.steps.instance_weight']).to include('must be an Integer between 1-100 (inclusive)')
            end

            it 'errors if any instance_weight is less than 0' do
              body['options'] = { canary: { steps: [{ instance_weight: -5 }, { instance_weight: 50 }] } }
              message = DeploymentCreateMessage.new(body)
              expect(message).not_to be_valid
              expect(message.errors[:'options.canary.steps.instance_weight']).to include('must be an Integer between 1-100 (inclusive)')
            end

            it 'errors if any instance_weight is greater than 100' do
              body['options'] = { canary: { steps: [{ instance_weight: 50 }, { instance_weight: 101 }] } }
              message = DeploymentCreateMessage.new(body)
              expect(message).not_to be_valid
              expect(message.errors[:'options.canary.steps.instance_weight']).to include('must be an Integer between 1-100 (inclusive)')
            end

            it 'errors if any instance_weights are not sorted in ascending order' do
              body['options'] = { canary: { steps: [{ instance_weight: 75 }, { instance_weight: 25 }] } }
              message = DeploymentCreateMessage.new(body)
              expect(message).not_to be_valid
              expect(message.errors[:'options.canary.steps.instance_weight']).to include('must be sorted in ascending order')
            end

            it 'errors if any instance_weights are a non-integer numeric' do
              body['options'] = { canary: { steps: [{ instance_weight: 2 }, { instance_weight: 25.0 }] } }
              message = DeploymentCreateMessage.new(body)
              expect(message).not_to be_valid
              expect(message.errors[:'options.canary.steps.instance_weight']).to include('must be an Integer between 1-100 (inclusive)')
            end
          end
        end
      end

      describe 'metadata' do
        context 'when the annotations params are valid' do
          let(:params) do
            {
              'metadata' => {
                'annotations' => {
                  'potato' => 'mashed'
                }
              }
            }
          end

          it 'is valid and correctly parses the annotations' do
            message = DeploymentCreateMessage.new(params)
            expect(message).to be_valid
            expect(message.annotations).to include(potato: 'mashed')
          end
        end

        context 'when the annotations params are not valid' do
          let(:params) do
            {
              'metadata' => {
                'annotations' => 'timmyd'
              }
            }
          end

          it 'is invalid' do
            message = DeploymentCreateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors[:metadata]).to include('\'annotations\' is not an object')
          end
        end
      end
    end

    describe 'web_instances' do
      context 'when options is not specified' do
        before do
          body['options'] = nil
        end

        it 'returns nil' do
          message = DeploymentCreateMessage.new(body)
          expect(message).to be_valid
          expect(message.web_instances).to be_nil
        end
      end

      context 'when web_instances is specified' do
        before do
          body['options'] = { 'web_instances' => 10 }
        end

        it 'returns the passed value' do
          message = DeploymentCreateMessage.new(body)
          expect(message).to be_valid
          expect(message.web_instances).to eq 10
        end
      end
    end

    describe 'max_in_flight' do
      context 'when options is not specified' do
        before do
          body['options'] = nil
        end

        it 'returns the default value of 1' do
          message = DeploymentCreateMessage.new(body)
          expect(message).to be_valid
          expect(message.max_in_flight).to be 1
        end
      end

      context 'when options is specified, but not max_in_flight' do
        before do
          body['options'] = { canary: nil }
        end

        it 'returns the default value of 1' do
          message = DeploymentCreateMessage.new(body)
          expect(message).to be_valid
          expect(message.max_in_flight).to be 1
        end
      end

      context 'when options.max_in_flight is set to nil' do
        before do
          body['options'] = { max_in_flight: nil }
        end

        it 'returns the default value of 1' do
          message = DeploymentCreateMessage.new(body)
          expect(message).to be_valid
          expect(message.max_in_flight).to be 1
        end
      end

      context 'when options.max_in_flight is specified' do
        before do
          body['options'] = { max_in_flight: 10 }
        end

        it 'returns the specified value' do
          message = DeploymentCreateMessage.new(body)
          expect(message).to be_valid
          expect(message.max_in_flight).to be 10
        end
      end
    end

    describe 'canary steps' do
      context 'when options is not specified' do
        before do
          body['options'] = nil
        end

        it 'returns nil' do
          message = DeploymentCreateMessage.new(body)
          expect(message.canary_steps).to be_nil
        end
      end

      context 'when canary and steps are specified' do
        before do
          body['options'] = { canary: { steps: [{ instance_weight: 1 }] } }
        end

        it 'returns the passed value' do
          message = DeploymentCreateMessage.new(body)
          expect(message.canary_steps).to eq [{ instance_weight: 1 }]
        end
      end
    end
  end
end
