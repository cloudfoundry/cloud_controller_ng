require 'spec_helper'
require 'messages/route_update_destinations_message'

module VCAP::CloudController
  RSpec.describe RouteUpdateDestinationsMessage do
    let(:replace) { false }
    subject(:message) { RouteUpdateDestinationsMessage.new(params, replace: replace) }

    context 'when the body has the correct structure' do
      let(:params) do
        {
          destinations: [
            {
              app: {
                guid: 'some-guid',
                process: {
                  type: 'web'
                }
              }
            }
          ]
        }
      end

      it 'is valid' do
        expect(subject).to be_valid
      end

      context 'when ports are specified' do
        let(:params) do
          {
            destinations: [
              {
                app: {
                  guid: 'some-guid',
                  process: {
                    type: 'web'
                  }
                },
                port: 8081
              }
            ]
          }
        end

        it 'is valid' do
          expect(subject).to be_valid
        end
      end
    end

    context 'when destinations is missing' do
      let(:params) { {} }

      it 'is not valid' do
        expect(subject).to be_invalid
        expect(subject.errors.full_messages).to contain_exactly(
          'Destinations must be an array containing between 1 and 100 destination objects.'
        )
      end
    end

    context 'when there are additional keys' do
      let(:params) { { potato: '' } }

      it 'is not valid' do
        expect(subject).to be_invalid
        expect(subject.errors.full_messages).to contain_exactly(
          "Unknown field(s): 'potato'",
          'Destinations must be an array containing between 1 and 100 destination objects.'
        )
      end
    end

    context 'when destinations is not an array' do
      let(:params) { { destinations: '' } }

      it 'is not valid' do
        expect(subject).to be_invalid
        expect(subject.errors.full_messages).to contain_exactly(
          'Destinations must be an array containing between 1 and 100 destination objects.'
        )
      end
    end

    context 'when destinations do not contain hashes' do
      let(:params) { { destinations: [''] } }

      it 'is not valid' do
        expect(subject).to be_invalid
        expect(subject.errors.full_messages).to contain_exactly(
          'Destinations[0]: must be an object.'
        )
      end
    end

    context 'when destinations are invalid' do
      context 'when the app key is missing' do
        let(:params) { { destinations: [{ potato: '' }] } }

        it 'is not valid' do
          expect(subject).to be_invalid
          expect(subject.errors.full_messages).to contain_exactly(
            'Destinations[0]: must have an "app".'
          )
        end
      end

      context 'when an invalid key is alongside the app key' do
        let(:params) { { destinations: [{ app: '', potato: '' }] } }
        it 'is not valid' do
          expect(subject).to be_invalid
          expect(subject.errors.full_messages).to contain_exactly(
            'Destinations[0]: must have only "app" and optionally "weight" and "port".'
          )
        end
      end

      context 'when app is not an object' do
        let(:params) { { destinations: [{ app: '' }] } }

        it 'is not valid' do
          expect(subject).to be_invalid
          expect(subject.errors.full_messages).to contain_exactly(
            'Destinations[0]: app must have the structure {"guid": "app_guid"}'
          )
        end
      end

      context 'when destination apps are malformed' do
        context 'when the guid key is missing' do
          let(:params) { { destinations: [{ app: { process: { type: 'web' } } }] } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors.full_messages).to contain_exactly(
              'Destinations[0]: app must have the structure {"guid": "app_guid"}'
            )
          end
        end

        context 'when additional keys are given' do
          let(:params) { { destinations: [{ app: { guid: '', not_allowed: '' } }] } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors.full_messages).to contain_exactly(
              'Destinations[0]: app must have the structure {"guid": "app_guid"}'
            )
          end
        end

        context 'when the guid is not a string' do
          let(:params) { { destinations: [{ app: { guid: 123 } }] } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors.full_messages).to contain_exactly(
              'Destinations[0]: app must have the structure {"guid": "app_guid"}'
            )
          end
        end

        context 'when there is a process specified' do
          context 'when the process is not an object' do
            let(:params) { { destinations: [{ app: { guid: 'guid', process: 3 } }] } }

            it 'is not valid' do
              expect(subject).to be_invalid
              expect(subject.errors.full_messages).to contain_exactly(
                'Destinations[0]: process must have the structure {"type": "process_type"}'
              )
            end
          end

          context 'when the type key is missing' do
            let(:params) { { destinations: [{ app: { guid: 'guid', process: { not_type: '' } } }] } }

            it 'is not valid' do
              expect(subject).to be_invalid
              expect(subject.errors.full_messages).to contain_exactly(
                'Destinations[0]: process must have the structure {"type": "process_type"}'
              )
            end
          end

          context 'when type is not a string' do
            let(:params) { { destinations: [{ app: { guid: 'guid', process: { type: 4 } } }] } }

            it 'is not valid' do
              expect(subject).to be_invalid
              expect(subject.errors.full_messages).to contain_exactly(
                'Destinations[0]: process must have the structure {"type": "process_type"}'
              )
            end
          end

          context 'when type is empty' do
            let(:params) { { destinations: [{ app: { guid: 'guid', process: { type: '' } } }] } }

            it 'is not valid' do
              expect(subject).to be_invalid
              expect(subject.errors.full_messages).to contain_exactly(
                'Destinations[0]: process must have the structure {"type": "process_type"}'
              )
            end
          end
        end

        context 'when there are multiple destinations with different errors' do
          let(:replace) { true }

          let(:params) do
            {
              destinations: [
                { app: { guid: 'valid-destination' } },
                { app: { guid: 'invalid-destination', process: 47 }, weight: 200 },
                'just-a-string'
              ]
            }
          end

          it 'returns all errors' do
            expect(subject).to be_invalid
            expect(subject.errors.full_messages).to contain_exactly(
              'Destinations[1]: process must have the structure {"type": "process_type"}',
              'Destinations[1]: weight must be a positive integer between 1 and 100.',
              'Destinations[2]: must be an object.'
            )
          end
        end
      end

      context 'when port is invalid' do
        let(:params) do
          {
            destinations: [
              {
                app: {
                  guid: 'some-guid',
                  process: {
                    type: 'web'
                  }
                },
                port: port
              }
            ]
          }
        end

        context 'when port is a string' do
          let(:port) { 'some-string' }
          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors.full_messages).to contain_exactly(
              'Destinations[0]: port must be a positive integer between 1024 and 65535 inclusive.'
            )
          end
        end
        context 'when port is less than 1024' do
          let(:port) { 1023 }
          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors.full_messages).to contain_exactly(
              'Destinations[0]: port must be a positive integer between 1024 and 65535 inclusive.'
            )
          end
        end
        context 'when port is greater than 65535' do
          let(:port) { 65536 }
          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors.full_messages).to contain_exactly(
              'Destinations[0]: port must be a positive integer between 1024 and 65535 inclusive.'
            )
          end
        end
      end

      context 'when there are more than 10 destinations' do
        context 'and all 10+ destinations are for the same app but different ports' do
          let(:params) do
            {
              destinations: (1..11).map { |i|
                {
                  app: {
                    guid: 'app-guid',
                    process: {
                      type: 'web'
                    }
                  },
                  port: 8080 + i
                }
              }
            }
          end

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors.full_messages).to contain_exactly(
              'Process must have at most 10 exposed ports.'
            )
          end
        end

        context 'and all 10+ combinations have unique process types' do
          let(:params) do
            {
              destinations: (1..100).map { |i|
                {
                  app: {
                    guid: 'app-guid',
                    process: {
                      type: "web-#{i}"
                    }
                  },
                  port: 8080
                }
              }
            }
          end

          it 'is valid' do
            expect(subject).to be_valid
          end
        end

        context 'when 100+ combinations have unique process types' do
          let(:params) do
            {
              destinations: (1..101).map { |i|
                {
                  app: {
                    guid: 'app-guid',
                    process: {
                      type: "web-#{i}"
                    }
                  },
                  port: 8080
                }
              }
            }
          end

          it 'is invalid' do
            expect(subject).to be_invalid
            expect(subject.errors.full_messages).to contain_exactly(
              'Destinations must be an array containing between 1 and 100 destination objects.'
            )
          end
        end
      end
    end

    context 'when destinations is an empty array' do
      let(:params) { { destinations: [] } }

      context 'when replacing destinations' do
        let(:replace) { true }

        it 'is valid' do
          expect(subject).to be_valid
        end
      end

      context 'when inserting destinations' do
        let(:replace) { false }

        it 'is not valid' do
          expect(subject).to be_invalid
          expect(subject.errors.full_messages).to contain_exactly('Destinations must be an array containing between 1 and 100 destination objects.')
        end
      end
    end

    describe 'weights' do
      context 'when inserting destinations' do
        let(:replace) { false }

        context 'when all destinations are unweighted' do
          let(:params) do
            {
              destinations: [
                {
                  app: { guid: 'app-guid' },
                },
                {
                  app: { guid: 'app-guid' },
                },
                {
                  app: { guid: 'app-guid' },
                },
              ]
            }
          end

          it 'is valid' do
            expect(subject).to be_valid
          end
        end

        context 'when destinations are weighted' do
          let(:params) do
            {
              destinations: [
                {
                  app: { guid: 'app-guid' },
                  weight: 30
                },
                {
                  app: { guid: 'app-guid' },
                  weight: 70
                }
              ]
            }
          end

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors.full_messages).to contain_exactly(
              'Destinations[0]: weighted destinations can only be used when replacing all destinations.',
              'Destinations[1]: weighted destinations can only be used when replacing all destinations.',
            )
          end
        end
      end

      context 'when replacing all destinations' do
        let(:replace) { true }

        context 'when the sum of the weights is 100' do
          let(:params) do
            {
              destinations: [
                {
                  app: { guid: 'app-guid' },
                  weight: 15
                },
                {
                  app: { guid: 'app-guid' },
                  weight: 30
                },
                {
                  app: { guid: 'app-guid' },
                  weight: 55
                },
              ]
            }
          end

          it 'is valid' do
            expect(subject).to be_valid
          end
        end

        context 'when all destinations are unweighted' do
          let(:params) do
            {
              destinations: [
                {
                  app: { guid: 'app-guid' },
                },
                {
                  app: { guid: 'app-guid' },
                },
                {
                  app: { guid: 'app-guid' },
                },
              ]
            }
          end

          it 'is valid' do
            expect(subject).to be_valid
          end
        end

        context 'a weight is not a integer' do
          let(:params) do
            {
              destinations: [
                {
                  app: {
                    guid: 'some-guid',
                    process: {
                      type: 'web'
                    }
                  },
                  weight: 'heavy'
                }
              ]
            }
          end
          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors.full_messages).to contain_exactly(
              'Destinations[0]: weight must be a positive integer between 1 and 100.'
            )
          end
        end

        context 'the weight is negative' do
          let(:params) do
            {
              destinations: [
                {
                  app: {
                    guid: 'some-guid',
                    process: {
                      type: 'web'
                    }
                  },
                  weight: -4
                }
              ]
            }
          end

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors.full_messages).to contain_exactly(
              'Destinations[0]: weight must be a positive integer between 1 and 100.'
            )
          end
        end

        context 'the weight a over 100' do
          let(:params) do
            {
              destinations: [
                {
                  app: {
                    guid: 'some-guid',
                    process: {
                      type: 'web'
                    }
                  },
                  weight: 101
                }
              ]
            }
          end

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors.full_messages).to contain_exactly(
              'Destinations[0]: weight must be a positive integer between 1 and 100.'
            )
          end
        end

        context 'when the sum of the weights is *not* 100' do
          let(:params) do
            {
              destinations: [
                {
                  app: { guid: 'app-guid' },
                  weight: 15
                },
              ]
            }
          end

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors.full_messages).to contain_exactly(
              'Destinations must have weights that sum to 100.'
            )
          end
        end

        context 'when only *some* destinations weighted' do
          let(:params) do
            {
              destinations: [
                {
                  app: { guid: 'app-guid' },
                  weight: 15
                },
                {
                  app: { guid: 'app-guid' }
                }
              ]
            }
          end

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors.full_messages).to contain_exactly(
              'Destinations cannot contain both weighted and unweighted destinations.'
            )
          end
        end
      end
    end

    describe 'destinations' do
      let(:params) do
        {
          destinations: [
            {
              app: {
                guid: 'some-guid',
                process: {
                  type: 'web'
                }
              }
            },
            {
              app: {
                guid: 'some-other-guid',
                process: {
                  type: 'web'
                }
              },
              port: 9000
            }
          ]
        }
      end

      it 'returns an array of destination hashes' do
        expect(subject.destinations_array).to eq([
          {
            app_guid: 'some-guid',
            process_type: 'web',
            app_port: nil,
            weight: nil,
          },
          {
            app_guid: 'some-other-guid',
            process_type: 'web',
            app_port: 9000,
            weight: nil,
          }
        ])
      end
    end
  end
end
