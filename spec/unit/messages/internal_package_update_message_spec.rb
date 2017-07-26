require 'spec_helper'
require 'messages/packages/internal_package_update_message'

module VCAP::CloudController
  RSpec.describe InternalPackageUpdateMessage do
    describe '.create_from_http_request' do
      let(:body) do
        { 'state'     => 'PROCESSING_UPLOAD',
          'checksums' => [
            {
              'type'  => 'sha1',
              'value' => 'potato'
            },
            {
              'type'  => 'sha256',
              'value' => 'potatoest'
            }
          ],
          'error' => 'something bad happened'
        }
      end

      it 'returns the correct InternalPackageUpdateMessaage' do
        message = InternalPackageUpdateMessage.create_from_http_request(body)

        expect(message).to be_a(InternalPackageUpdateMessage)
        expect(message.state).to eq('PROCESSING_UPLOAD')
        expect(message.error).to eq('something bad happened')
        expect(message.sha1).to eq('potato')
        expect(message.sha256).to eq('potatoest')
      end

      it 'does not mutate the original request body object' do
        InternalPackageUpdateMessage.create_from_http_request(body)
        expect(body['state']).to eq 'PROCESSING_UPLOAD'
      end

      it 'converts requested keys to symbols' do
        message = InternalPackageUpdateMessage.create_from_http_request(body)

        expect(message.requested?(:state)).to be_truthy
      end
    end

    describe 'validations' do
      context 'when unexpected keys are requested' do
        let(:body) do
          { 'state'     => 'PROCESSING_UPLOAD',
            'checksums' => [
              {
                'type'  => 'sha1',
                'value' => 'potato'
              },
              {
                'type'  => 'sha256',
                'value' => 'potatoest'
              }
            ],
            'error'     => 'something bad happened',
            'extra'     => 'some-key'
          }
        end

        it 'is not valid' do
          message = InternalPackageUpdateMessage.create_from_http_request(body)

          expect(message).to be_invalid
          expect(message.errors.full_messages[0]).to include("Unknown field(s): 'extra'")
        end
      end

      describe 'state' do
        let(:body) do
          { 'state'     => state,
            'checksums' => [
              {
                'type'  => 'sha1',
                'value' => 'potato'
              },
              {
                'type'  => 'sha256',
                'value' => 'potatoest'
              }
            ],
            'error' => 'something bad happened'
          }
        end

        context 'when state is PROCESSING_UPLOAD' do
          let(:state) { PackageModel::PENDING_STATE }

          it 'is valid' do
            message = InternalPackageUpdateMessage.create_from_http_request(body)

            expect(message).to be_valid
          end
        end

        context 'when state is READY' do
          let(:state) { PackageModel::READY_STATE }

          it 'is valid' do
            message = InternalPackageUpdateMessage.create_from_http_request(body)

            expect(message).to be_valid
          end
        end

        context 'when state is FAILED' do
          let(:state) { PackageModel::FAILED_STATE }

          it 'is valid' do
            message = InternalPackageUpdateMessage.create_from_http_request(body)

            expect(message).to be_valid
          end
        end

        context 'when state is AWAITING_UPLOAD' do
          let(:state) { PackageModel::CREATED_STATE }

          it 'is invalid' do
            message = InternalPackageUpdateMessage.create_from_http_request(body)

            expect(message).to be_invalid
            expect(message.errors[:state]).to include('must be one of PROCESSING_UPLOAD, READY, FAILED')
          end
        end

        context 'when state is COPYING' do
          let(:state) { PackageModel::COPYING_STATE }

          it 'is invalid' do
            message = InternalPackageUpdateMessage.create_from_http_request(body)

            expect(message).to be_invalid
            expect(message.errors[:state]).to include('must be one of PROCESSING_UPLOAD, READY, FAILED')
          end
        end

        context 'when state is EXPIRED' do
          let(:state) { PackageModel::EXPIRED_STATE }

          it 'is invalid' do
            message = InternalPackageUpdateMessage.create_from_http_request(body)

            expect(message).to be_invalid
            expect(message.errors[:state]).to include('must be one of PROCESSING_UPLOAD, READY, FAILED')
          end
        end

        context 'when state is not a valid package state' do
          let(:state) { 'bogus' }

          it 'is invalid' do
            message = InternalPackageUpdateMessage.create_from_http_request(body)

            expect(message).to be_invalid
            expect(message.errors[:state]).to include('must be one of PROCESSING_UPLOAD, READY, FAILED')
          end
        end
      end

      describe 'checksum' do
        let(:checksums) do
          [
            {
              'type'  => 'sha1',
              'value' => 'potato'
            },
            {
              'type'  => 'sha256',
              'value' => 'potatoest'
            }
          ]
        end

        let(:body) do
          {
            'state'     => 'READY',
            'checksums' => checksums
          }
        end

        describe 'structure' do
          context 'when there is an extra key' do
            let(:checksums) do
              [
                {
                  'type'  => 'sha1',
                  'value' => 'potato',
                  'extra' => 'something'
                },
                {
                  'type'  => 'sha256',
                  'value' => 'potatoest'
                }
              ]
            end

            it 'is not valid' do
              message = InternalPackageUpdateMessage.create_from_http_request(body)

              expect(message).to be_invalid
              expect(message.errors.full_messages[0]).to include("Unknown field(s): 'extra'")
            end
          end

          context 'when only sha1 is provided' do
            let(:checksums) do
              [
                {
                  'type'  => 'sha1',
                  'value' => 'potato'
                },
                {
                  'type'  => 'sha1',
                  'value' => 'potato'
                }
              ]
            end

            it 'is not valid' do
              message = InternalPackageUpdateMessage.create_from_http_request(body)

              expect(message).to be_invalid
              expect(message.errors['checksums']).to include('both sha1 and sha256 checksums must be provided')
            end
          end

          context 'when only sha256 is provided' do
            let(:checksums) do
              [
                {
                  'type'  => 'sha256',
                  'value' => 'potato'
                },
                {
                  'type'  => 'sha256',
                  'value' => 'potato'
                }
              ]
            end

            it 'is not valid' do
              message = InternalPackageUpdateMessage.create_from_http_request(body)

              expect(message).to be_invalid
              expect(message.errors['checksums']).to include('both sha1 and sha256 checksums must be provided')
            end
          end

          context 'when more than two types are provided' do
            let(:checksums) do
              [
                {
                  'type'  => 'sha256',
                  'value' => 'potato'
                },
                {
                  'type'  => 'sha256',
                  'value' => 'potato'
                },
                {
                  'type'  => 'sha1',
                  'value' => 'potato'
                }
              ]
            end

            it 'is not valid' do
              message = InternalPackageUpdateMessage.create_from_http_request(body)

              expect(message).to be_invalid
              expect(message.errors['checksums']).to include('both sha1 and sha256 checksums must be provided')
            end
          end

          context 'when no checksums are provided' do
            let(:body) do
              {
                'state' => 'FAILED',
              }
            end

            it 'is valid' do
              message = InternalPackageUpdateMessage.create_from_http_request(body)

              expect(message).to be_valid
            end
          end
        end

        describe 'type' do
          context 'when types are sha1 and sha256' do
            it 'is valid' do
              message = InternalPackageUpdateMessage.create_from_http_request(body)

              expect(message).to be_valid
            end
          end

          context 'when one of the types is invalid' do
            let(:checksums) do
              [
                {
                  'type'  => 'bogus',
                  'value' => 'potato'
                },
                {
                  'type'  => 'sha256',
                  'value' => 'potatoest'
                }
              ]
            end

            it 'is not valid' do
              message = InternalPackageUpdateMessage.create_from_http_request(body)

              expect(message).to be_invalid
              expect(message.errors[:checksums]).to include('Type must be one of sha1, sha256')
            end
          end
        end

        describe 'value' do
          context 'when shorter than 1 character' do
            let(:checksums) do
              [
                {
                  'type'  => 'sha1',
                  'value' => ''
                },
                {
                  'type'  => 'sha256',
                  'value' => 'potatoest'
                }
              ]
            end

            it 'is not valid' do
              message = InternalPackageUpdateMessage.create_from_http_request(body)

              expect(message).to be_invalid
              expect(message.errors[:checksums]).to include('Value must be between 1 and 500 characters')
            end
          end

          context 'when longer than 500 characters' do
            let(:checksums) do
              [
                {
                  'type'  => 'sha1',
                  'value' => 'a' * 501
                },
                {
                  'type'  => 'sha256',
                  'value' => 'potatoest'
                }
              ]
            end

            it 'is not valid' do
              message = InternalPackageUpdateMessage.create_from_http_request(body)

              expect(message).to be_invalid
              expect(message.errors[:checksums]).to include('Value must be between 1 and 500 characters')
            end
          end

          context 'when between 1 and 500 characters' do
            let(:checksums) do
              [
                {
                  'type'  => 'sha1',
                  'value' => 'a'
                },
                {
                  'type'  => 'sha256',
                  'value' => 'potatoest'
                }
              ]
            end

            it 'is valid' do
              message = InternalPackageUpdateMessage.create_from_http_request(body)

              expect(message).to be_valid
            end
          end
        end
      end

      describe 'error' do
        let(:body) do
          {
            'state' => 'FAILED',
            'error' => error
          }
        end

        context 'when not present' do
          let(:error) { nil }

          it 'is valid' do
            message = InternalPackageUpdateMessage.create_from_http_request(body)

            expect(message).to be_valid
          end
        end

        context 'when shorter than 1 character' do
          let(:error) { '' }

          it 'is not valid' do
            message = InternalPackageUpdateMessage.create_from_http_request(body)

            expect(message).to be_invalid
            expect(message.errors[:error]).to include('must be between 1 and 500 characters')
          end
        end

        context 'when longer than 500 characters' do
          let(:error) { 'a' * 501 }

          it 'is not valid' do
            message = InternalPackageUpdateMessage.create_from_http_request(body)

            expect(message).to be_invalid
            expect(message.errors[:error]).to include('must be between 1 and 500 characters')
          end
        end

        context 'when between 1 and 500 characters' do
          let(:error) { 'a' }

          it 'is valid' do
            message = InternalPackageUpdateMessage.create_from_http_request(body)

            expect(message).to be_valid
          end
        end
      end
    end
  end
end
