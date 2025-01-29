require 'spec_helper'

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
            expect(message.errors_on(:metadata)).to include('\'annotations\' is not an object')
          end
        end
      end
    end

    describe 'max_in_flight' do
      context 'when objects is not specified' do
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
          body['options'] = { other_key: 'other_value' }
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

    describe 'canary options' do
      before do
        body['strategy'] = 'canary'
      end

      context 'when options.canary is a hash"' do
        before do
          body['options'] = { canary: { my_option: 'foo' } }
        end

        it 'is valid' do
          message = DeploymentCreateMessage.new(body)
          expect(message).to be_valid
          expect(message.canary_options).to eq({ my_option: 'foo' })
        end
      end

      context 'when options.canary is not a hash"' do
        before do
          body['options'] = { canary: 'I should be a hash' }
        end

        it 'is invalid' do
          message = DeploymentCreateMessage.new(body)
          expect(message).not_to be_valid
          expect(message.errors_on(:canary_options)).to include('must be an object')
        end
      end

      context 'when options.canary is specified but strategy is "rolling"' do
        before do
          body['strategy'] = 'rolling'
          body['options'] = { canary: { my_option: 'foo' } }
        end

        it 'errors' do
          message = DeploymentCreateMessage.new(body)
          expect(message).not_to be_valid
          expect(message.errors.full_messages).to include('Canary options are only valid for Canary deployments')
        end
      end
    end

    describe 'canary steps' do
      context 'when objects is not specified' do
        before do
          body['options'] = nil
        end

        it 'returns the default value of empty array' do
          message = DeploymentCreateMessage.new(body)
          expect(message).to be_valid
          expect(message.canary_steps).to eq []
        end
      end

      context 'when options.canary_steps is specified' do
        before do
          body['strategy'] = 'canary'
          body['options'] = { canary: {
            steps: [
              { instance_weight: 20 },
              { instance_weight: 40 },
              { instance_weight: 60 },
              { instance_weight: 80 }
            ]
          } }
        end

        # TODO: Perhaps this should be converted to an `instance_weights` property?
        it 'returns the array of weights' do
          message = DeploymentCreateMessage.new(body)
          expect(message).to be_valid
          expect(message.canary_steps).to eq [
            { instance_weight: 20 },
            { instance_weight: 40 },
            { instance_weight: 60 },
            { instance_weight: 80 }
          ]
        end
      end

      context 'when options.canary_steps is not an array' do
        before do
          body['strategy'] = 'canary'
          body['options'] = { canary: {
            steps: { instance_weight: 80 }
          } }
        end

        # TODO: Perhaps this should be converted to an `instance_weights` property?
        it 'errors' do
          message = DeploymentCreateMessage.new(body)
          expect(message).not_to be_valid
          expect(message.errors.full_messages).to include('Canary steps must be an array')
        end
      end

      context 'validations' do
        context 'when one object in the array is missing "instance_weight"'
        context 'when one object in the array has a bad key"'
        context 'when one instance_weight is below 0'
        context 'when one instance_weight is above 100'
        context 'when an instance weight is a decimal or non-integer'
        context 'when canary steps is an empty array'
      end
    end
  end
end
