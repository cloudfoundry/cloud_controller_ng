require 'spec_helper'
require 'messages/app_create_message'

module VCAP::CloudController
  describe AppCreateMessage do
    describe '.create_from_http_request' do
      let(:body) {
        {
          'name'                  => 'some-name',
          'environment_variables' => {
            'ENVVAR' => 'env-val'
          },
          'relationships'         => {
            'space' => { 'guid' => 'some-guid' }
          },
          'lifecycle' => {
              'type'  => 'buildpack',
              'data'  => {
                'buildpack' => 'some-buildpack',
                'stack'     => 'some-stack'
              }
          }
        }
      }

      it 'returns the correct AppCreateMessage' do
        message = AppCreateMessage.create_from_http_request(body)

        expect(message).to be_a(AppCreateMessage)
        expect(message.name).to eq('some-name')
        expect(message.space_guid).to eq('some-guid')
        expect(message.environment_variables).to eq({ 'ENVVAR' => 'env-val' })
        expect(message.relationships).to eq({ 'space' => { 'guid' => 'some-guid' } })
        expect(message.lifecycle).to eq(
            { 'type'  => 'buildpack',
              'data'  => {
                'buildpack' => 'some-buildpack',
                'stack'     => 'some-stack'
              }
            })
      end

      it 'converts requested keys to symbols' do
        message = AppCreateMessage.create_from_http_request(body)

        expect(message.requested?(:name)).to be_truthy
        expect(message.requested?(:relationships)).to be_truthy
        expect(message.requested?(:environment_variables)).to be_truthy
        expect(message.requested?(:lifecycle)).to be_truthy
      end
    end

    describe 'validations' do
      context 'when unexpected keys are requested' do
        let(:params) { { unexpected: 'foo' } }

        it 'is not valid' do
          message = AppCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:base]).to include("Unknown field(s): 'unexpected'")
        end
      end

      context 'when name is not a string' do
        let(:params) { { name: 32.77 } }

        it 'is not valid' do
          message = AppCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors_on(:name)).to include('must be a string')
        end
      end

      context 'when environment_variables is not a hash' do
        let(:params) do
          {
            name:                  'name',
            environment_variables: 'potato',
            relationships:         { space: { guid: 'guid' } }
          }
        end

        it 'is not valid' do
          message = AppCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors_on(:environment_variables)[0]).to include('must be a hash')
        end
      end

      describe 'relationships' do
        context 'when relationships is malformed' do
          let(:params) { { name: 'name', relationships: 'malformed shizzle' } }

          it 'is not valid' do
            message = AppCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships)).to include('must be a hash')
          end
        end

        context 'when relationships is missing' do
          let(:params) { { name: 'name' } }

          it 'is not valid' do
            message = AppCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships)).to include("can't be blank")
          end
        end

        context 'when space is missing' do
          let(:params) do
            {
              name:          'name',
              relationships: {}
            }
          end

          it 'is not valid' do
            message = AppCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships)).to include("can't be blank")
          end
        end

        context 'when space has an invalid guid' do
          let(:params) do
            {
              name:          'name',
              relationships: { space: { guid: 32 } }
            }
          end

          it 'is not valid' do
            message = AppCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships).any? { |e| e.include?('Space guid') }).to be(true)
          end
        end

        context 'when space is malformed' do
          let(:params) do
            {
              name:          'name',
              relationships: { space: 'asdf' }
            }
          end

          it 'is not valid' do
            message = AppCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors_on(:relationships).any? { |e| e.include?('Space must be structured like') }).to be(true)
          end
        end

        context 'when additional keys are present' do
          let(:params) do
            {
              name:          'name',
              relationships: {
                space: { guid: 'guid' },
                other: 'stuff'
              }
            }
          end

          it 'is not valid' do
            message = AppCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors[:relationships]).to include("Unknown field(s): 'other'")
          end
        end
      end

      describe 'lifecycle' do
        context 'when lifecycle is provided' do
          let(:params) do
            {
              name: 'some_name',
              relationships: { space: { guid: 'some-guid' } },
              lifecycle: {
                type: 'buildpack',
                data: {
                  buildpack: 'java',
                  stack: 'cflinuxfs2'
                }
              }
            }
          end

          it 'is valid' do
            message = AppCreateMessage.new(params)
            expect(message).to be_valid
          end
        end

        context 'when lifecycle data is provided' do
          let(:params) do
            {
              lifecycle: {
                type: 'buildpack',
                data: {
                  buildpack: 123,
                  stack: 'fake-stack'
                }
              }
            }
          end

          it 'must provide a valid buildpack value' do
            message = AppCreateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors_on(:lifecycle)).to include('Buildpack must be a string')
          end

          it 'must provide a valid stack name' do
            message = AppCreateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors_on(:lifecycle)).to include('Stack must exist in our DB')
          end
        end

        context 'when data is not provided' do
          let(:params) do { lifecycle: { type: 'buildpack' } } end

          it 'is not valid' do
            message = AppCreateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors_on(:lifecycle_data)).to include('must be a hash')
          end
        end

        context 'when lifecycle data type is not valid' do
          let(:params) do { lifecycle: { data: {}, type: { subhash: 'woah!' } } } end

          it 'is not valid' do
            message = AppCreateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors_on(:lifecycle_type)).to include('is not included in the list')
          end
        end

        context 'when lifecycle is not provided' do
          let(:params) do
            {
              name: 'some_name',
              relationships: { space: { guid: 'some-guid' } }
            }
          end

          it 'defaults to buildpack' do
            message = AppCreateMessage.new(params)
            expect(message).to be_valid

            expect(message.lifecycle[:type]).to eq('buildpack')
            expect(message.lifecycle[:data][:stack]).to eq(Stack.default.name)
          end
        end
      end
    end
  end
end
