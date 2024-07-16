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
  end
end
