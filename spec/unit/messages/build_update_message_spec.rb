require 'spec_helper'
require 'messages/build_update_message'

module VCAP::CloudController
  RSpec.describe BuildUpdateMessage do
    describe 'validations' do
      context 'metadata' do
        let(:body) do
          {
            metadata: {
              labels: {
                potato: 'mashed'
              },
              annotations: {
                cheese: 'bono'
              }
            }
          }
        end
        it 'validates that there are not excess fields' do
          body['bogus'] = 'field'
          message = BuildUpdateMessage.new(body)

          expect(message).to_not be_valid
          expect(message.errors.full_messages).to include("Unknown field(s): 'bogus'")
        end

        it 'validates metadata' do
          message = BuildUpdateMessage.new(body)

          expect(message).to be_valid
        end

        it 'complains about bogus metadata fields' do
          newbody = body.merge({ metadata: { choppers: 3 } })
          message = BuildUpdateMessage.new(newbody)

          expect(message).not_to be_valid
        end
      end

      context 'state updates' do
        let(:body) do
          {
            state: 'STAGED',
            error: 'error',
            lifecycle: {
              type: 'kpack',
              data: {
                image: 'some-image:tag',
              }
            }
          }
        end

        it 'confirms state and error are valid' do
          message = BuildUpdateMessage.new(body)

          expect(message).to be_valid
        end

        context 'null error' do
          let(:body) do
            {
              state: 'STAGED',
              lifecycle: {
                type: 'kpack',
                data: {
                  image: 'some-image:tag',
                }
              }
            }
          end

          it 'allows a null error' do
            message = BuildUpdateMessage.new(body)

            expect(message).to be_valid
          end
        end

        it 'validates that there are not excess fields' do
          body['bogus'] = 'field'
          message = BuildUpdateMessage.new(body)

          expect(message).to_not be_valid
          expect(message.errors.full_messages).to include("Unknown field(s): 'bogus'")
        end

        context 'state is invalid' do
          let(:body) do
            {
              state: 'something',
              error: 'error'
            }
          end

          it 'complains if state is not valid' do
            message = BuildUpdateMessage.new(body)

            expect(message).not_to be_valid
            expect(message.errors[:state]).to include("'something' is not a valid state")
          end
        end

        context 'error is invalid' do
          let(:body) do
            {
              state: 'STAGED',
              error: {
                is_a: 'hash'
              }
            }
          end

          it 'complains if error is not valid' do
            message = BuildUpdateMessage.new(body)

            expect(message).not_to be_valid
            expect(message.errors[:error]).to include('must be a string')
          end
        end

        it 'complains about bogus metadata fields' do
          newbody = body.merge({ metadata: { choppers: 3 } })
          message = BuildUpdateMessage.new(newbody)

          expect(message).not_to be_valid
        end

        context 'staged state update omits lifecycle data' do
          let(:body) do
            {
              state: 'STAGED',
            }
          end

          it 'complains' do
            message = BuildUpdateMessage.new(body)
            expect(message).not_to be_valid

            expect(message.errors[:lifecycle]).to include("'STAGED' builds require lifecycle data")
          end
        end

        context 'build is in a failed state' do
          let(:body) do
            {
              state: 'FAILED',
              error: 'failed to stage build'
            }
          end

          it 'allows failed state message' do
            message = BuildUpdateMessage.new(body)

            expect(message).to be_valid
          end
        end
      end
    end
  end
end
