require 'spec_helper'
require 'messages/isolation_segment_update_message'

module VCAP::CloudController
  RSpec.describe IsolationSegmentUpdateMessage do
    describe 'validations' do
      context 'when unexpected keys are requested' do
        let(:params) {
          {
            name: 'some-name',
            unexpected: 'an-unexpected-value',
          }
        }

        it 'is not valid' do
          message = IsolationSegmentUpdateMessage.new(params)

          expect(message).to_not be_valid
          expect(message.errors[:base]).to include("Unknown field(s): 'unexpected'")
        end

        context 'when the name is not a string' do
          let(:params) do
            {
              name: 32.77,
            }
          end

          it 'is not valid' do
            message = IsolationSegmentUpdateMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors_on(:name)).to include('must be a string')
          end
        end
      end

      describe 'metadata' do
        context 'when the metadata is valid' do
          let(:params) do
            {
              metadata: {
                annotations: {
                  potato: 'mashed'
                },
                labels: {
                  foo: 'bar'
                }
              }
            }
          end

          context 'with a name' do
            let(:final_params) { params.merge({ name: 'new-name' }) }

            it 'is valid and correctly parses the annotations' do
              message = IsolationSegmentUpdateMessage.new(final_params)
              expect(message).to be_valid
              expect(message.annotations).to include(potato: 'mashed')
              expect(message.labels).to include(foo: 'bar')
              expect(message.name).to eq('new-name')
            end
          end

          context 'with no name' do
            let(:final_params) { params }

            it 'is valid and correctly parses the annotations' do
              message = IsolationSegmentUpdateMessage.new(final_params)
              expect(message).to be_valid
              expect(message.annotations).to include(potato: 'mashed')
              expect(message.labels).to include(foo: 'bar')
            end
          end

          context 'with a non-string name' do
            let(:final_params) { params.merge({ name: 5 }) }

            it 'is valid and correctly parses the annotations' do
              message = IsolationSegmentUpdateMessage.new(final_params)
              expect(message).not_to be_valid
            end
          end
        end

        context 'when the annotations params are not valid' do
          let(:params) do
            {
              name: 'some-name',
              metadata: {
                annotations: 'timmyd'
              }
            }
          end

          it 'is invalid' do
            message = IsolationSegmentUpdateMessage.new(params)
            expect(message).not_to be_valid
            expect(message.errors_on(:metadata)).to include('\'annotations\' is not an object')
          end
        end
      end
    end
  end
end
