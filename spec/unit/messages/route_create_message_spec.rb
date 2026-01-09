require 'spec_helper'
require 'messages/route_create_message'

module VCAP::CloudController
  RSpec.describe RouteCreateMessage do
    subject { RouteCreateMessage.new(params) }

    describe 'validations' do
      context 'when valid params are given' do
        let(:params) do
          {
            host: 'some-host',
            port: 123,
            path: '/some-path',
            relationships: {
              space: { data: { guid: 'space-guid' } },
              domain: { data: { guid: 'domain-guid' } }
            },
            metadata: {
              labels: { potato: 'yam' },
              annotations: { style: 'mashed' }
            },
            options: {
              loadbalancing: 'round-robin'
            }
          }
        end

        it 'is valid' do
          expect(subject).to be_valid
        end
      end

      context 'when no params are given' do
        let(:params) {}

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors[:relationships]).to include("can't be blank")
        end
      end

      context 'when unexpected keys are requested' do
        let(:params) do
          {
            relationships: {
              space: { data: { guid: 'space-guid' } },
              domain: { data: { guid: 'domain-guid' } }
            },
            unexpected: 'meow'
          }
        end

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
        end
      end

      context 'host' do
        context 'when not provided' do
          let(:params) do
            {
              relationships: {
                space: { data: { guid: 'space-guid' } },
                domain: { data: { guid: 'domain-guid' } }
              }
            }
          end

          it 'is valid' do
            expect(subject).to be_valid
          end
        end

        context 'when not a string' do
          let(:params) do
            { host: 5 }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:host]).to include('must be a string')
          end
        end

        context 'when an empty string' do
          let(:params) do
            {
              host: '',
              relationships: {
                space: { data: { guid: 'space-guid' } },
                domain: { data: { guid: 'domain-guid' } }
              }
            }
          end

          it 'is valid' do
            expect(subject).to be_valid
          end
        end

        context 'when it is too long' do
          let(:params) { { host: 'B' * (RouteCreateMessage::MAXIMUM_DOMAIN_LABEL_LENGTH + 1) } }

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:host]).to include "is too long (maximum is #{RouteCreateMessage::MAXIMUM_DOMAIN_LABEL_LENGTH} characters)"
          end
        end

        context 'when it contains non-alphanumeric characters other than - and _' do
          let(:params) { { host: 'somethingwitha.' } }

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:host]).to match ['must be either "*" or contain only alphanumeric characters, "_", or "-"']
          end
        end

        context 'when its a wildcard' do
          let(:params) do
            {
              host: '*',
              relationships: {
                space: { data: { guid: 'space-guid' } },
                domain: { data: { guid: 'domain-guid' } }
              }
            }
          end

          it 'is valid' do
            expect(subject).to be_valid
          end
        end
      end

      context 'port' do
        context 'when not provided' do
          let(:params) do
            {
              host: 'some-host',
              relationships: {
                space: { data: { guid: 'space-guid' } },
                domain: { data: { guid: 'domain-guid' } }
              }
            }
          end

          it 'is valid' do
            expect(subject).to be_valid
          end
        end

        context 'when not an integer' do
          let(:params) do
            { port: 'some-string' }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:port]).to include('is not a number')
          end
        end

        context 'when it is too large' do
          let(:params) do
            { port: 65_536 }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:port]).to include 'must be less than or equal to 65535'
          end
        end

        context 'when it is negative' do
          let(:params) do
            { port: -5 }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:port]).to include 'must be greater than or equal to 0'
          end
        end
      end

      context 'path' do
        context 'when not provided' do
          let(:params) do
            {
              relationships: {
                space: { data: { guid: 'space-guid' } },
                domain: { data: { guid: 'domain-guid' } }
              }
            }
          end

          it 'is valid' do
            expect(subject).to be_valid
          end
        end

        context 'when not a string' do
          let(:params) do
            { path: 5 }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:path]).to include('must be a string')
          end
        end

        context 'when an empty string' do
          let(:params) do
            {
              path: '',
              relationships: {
                space: { data: { guid: 'space-guid' } },
                domain: { data: { guid: 'domain-guid' } }
              }
            }
          end

          it 'is valid' do
            expect(subject).to be_valid
          end
        end

        context 'when it is too long' do
          let(:params) { { path: 'B' * (RouteCreateMessage::MAXIMUM_PATH_LENGTH + 1) } }

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:path]).to include "is too long (maximum is #{RouteCreateMessage::MAXIMUM_PATH_LENGTH} characters)"
          end
        end

        context 'when it contains a ?' do
          let(:params) { { path: '/pathwith?' } }

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:path]).to match ['cannot contain ?']
          end
        end

        context 'when is exactly /' do
          let(:params) { { path: '/' } }

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:path]).to match ['cannot be exactly /']
          end
        end

        context 'when it doesn not begin with a /' do
          let(:params) { { path: 'some-path/' } }

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:path]).to match ['must begin with /']
          end
        end
      end

      context 'relationships' do
        context 'relationships is not an object' do
          let(:params) { { relationships: 'banana' } }

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:relationships]).to include "'relationships' is not an object"
          end
        end

        context 'when space is missing' do
          let(:params) do
            {
              relationships: {}
            }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors_on(:relationships)).to include("'relationships' must include one or more valid relationships")
          end
        end

        context 'when space has an invalid guid' do
          let(:params) do
            {
              relationships: { space: { data: { guid: 32 } } }
            }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors_on(:relationships)).to include(include('Space guid'))
          end
        end

        context 'when space is malformed' do
          let(:params) do
            {
              relationships: { space: 'asdf' }
            }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors_on(:relationships)).to include(include('Space must be structured like'))
          end
        end

        context 'when domain has an invalid guid' do
          let(:params) do
            {
              relationships: { domain: { data: { guid: 32 } } }
            }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors_on(:relationships)).to include(include('Domain guid'))
          end
        end

        context 'when domain is malformed' do
          let(:params) do
            {
              relationships: { domain: 'asdf' }
            }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors_on(:relationships)).to include(include('Domain must be structured like'))
          end
        end

        context 'when additional keys are present' do
          let(:params) do
            {
              relationships: {
                space: { data: { guid: 'guid' } },
                other: 'stuff'
              }
            }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:relationships]).to include("Unknown field(s): 'other'")
          end
        end
      end

      context 'options' do
        context 'when not provided' do
          let(:params) do
            {
              host: 'some-host',
              relationships: {
                space: { data: { guid: 'space-guid' } },
                domain: { data: { guid: 'domain-guid' } }
              }
            }
          end

          it 'is valid' do
            expect(subject).to be_valid
          end
        end

        context 'when empty' do
          let(:params) do
            {
              host: 'some-host',
              relationships: {
                space: { data: { guid: 'space-guid' } },
                domain: { data: { guid: 'domain-guid' } }
              },
              options: {}
            }
          end

          it 'is valid' do
            expect(subject).to be_valid
          end
        end

        context 'when nil' do
          let(:params) do
            {
              host: 'some-host',
              relationships: {
                space: { data: { guid: 'space-guid' } },
                domain: { data: { guid: 'domain-guid' } }
              },
              options: nil
            }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:options]).to include("'options' is not a valid object")
          end
        end

        context 'when options has invalid key' do
          let(:params) do
            {
              host: 'some-host',
              relationships: {
                space: { data: { guid: 'space-guid' } },
                domain: { data: { guid: 'domain-guid' } }
              },
              options: { foobar: 'baz' }
            }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:options]).to include("Unknown field(s): 'foobar'")
          end
        end

        context 'when loadbalancing has value round-robin' do
          let(:params) do
            {
              host: 'some-host',
              relationships: {
                space: { data: { guid: 'space-guid' } },
                domain: { data: { guid: 'domain-guid' } }
              },
              options: { loadbalancing: 'round-robin' }
            }
          end

          it 'is valid' do
            expect(subject).to be_valid
          end

          context 'when loadbalancing has value least-connection' do
            let(:params) do
              {
                host: 'some-host',
                relationships: {
                  space: { data: { guid: 'space-guid' } },
                  domain: { data: { guid: 'domain-guid' } }
                },
                options: { loadbalancing: 'least-connection' }
              }
            end

            it 'is valid' do
              expect(subject).to be_valid
            end
          end

          context 'when loadbalancing is nil' do
            let(:params) do
              {
                host: 'some-host',
                relationships: {
                  space: { data: { guid: 'space-guid' } },
                  domain: { data: { guid: 'domain-guid' } }
                },
                options: { loadbalancing: nil }
              }
            end

            it 'is valid' do
              expect(subject).to be_valid
            end
          end

          context 'when loadbalancing has invalid value' do
            let(:params) do
              {
                host: 'some-host',
                relationships: {
                  space: { data: { guid: 'space-guid' } },
                  domain: { data: { guid: 'domain-guid' } }
                },
                options: { loadbalancing: 'random' }
              }
            end

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:options]).to include("Loadbalancing must be one of 'round-robin, least-connection' if present")
            end
          end
        end

        context 'when hash_based_routing feature flag is enabled' do
          before do
            VCAP::CloudController::FeatureFlag.make(name: 'hash_based_routing', enabled: true)
          end

          context 'when hash_header is longer than 128 characters' do
            let(:params) do
              {
                host: 'some-host',
                relationships: {
                  space: { data: { guid: 'space-guid' } },
                  domain: { data: { guid: 'domain-guid' } }
                },
                options: {
                  loadbalancing: 'hash',
                  hash_header: 'X' * 129
                }
              }
            end

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:options]).to include('Hash header must be at most 128 characters')
            end
          end

          context 'when hash_header is exactly 128 characters' do
            let(:params) do
              {
                host: 'some-host',
                relationships: {
                  space: { data: { guid: 'space-guid' } },
                  domain: { data: { guid: 'domain-guid' } }
                },
                options: {
                  loadbalancing: 'hash',
                  hash_header: 'X' * 128
                }
              }
            end

            it 'is valid' do
              expect(subject).to be_valid
            end
          end

          context 'when hash_balance is longer than 16 characters' do
            let(:params) do
              {
                host: 'some-host',
                relationships: {
                  space: { data: { guid: 'space-guid' } },
                  domain: { data: { guid: 'domain-guid' } }
                },
                options: {
                  loadbalancing: 'hash',
                  hash_header: 'X-User-ID',
                  hash_balance: '12345678901234567'
                }
              }
            end

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:options]).to include('Hash balance must be at most 16 characters')
            end
          end

          context 'when hash_balance is exactly 16 characters' do
            let(:params) do
              {
                host: 'some-host',
                relationships: {
                  space: { data: { guid: 'space-guid' } },
                  domain: { data: { guid: 'domain-guid' } }
                },
                options: {
                  loadbalancing: 'hash',
                  hash_header: 'X-User-ID',
                  hash_balance: '9.9'
                }
              }
            end

            it 'is valid' do
              expect(subject).to be_valid
            end
          end

          context 'when hash_balance is greater than 10.0' do
            let(:params) do
              {
                host: 'some-host',
                relationships: {
                  space: { data: { guid: 'space-guid' } },
                  domain: { data: { guid: 'domain-guid' } }
                },
                options: {
                  loadbalancing: 'hash',
                  hash_header: 'X-User-ID',
                  hash_balance: 10.1
                }
              }
            end

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:options]).to include('Hash balance must be either 0 or between 1.1 and 10.0')
            end
          end

          context 'when hash_balance is exactly 10.0' do
            let(:params) do
              {
                host: 'some-host',
                relationships: {
                  space: { data: { guid: 'space-guid' } },
                  domain: { data: { guid: 'domain-guid' } }
                },
                options: {
                  loadbalancing: 'hash',
                  hash_header: 'X-User-ID',
                  hash_balance: 10.0
                }
              }
            end

            it 'is valid' do
              expect(subject).to be_valid
            end
          end
        end
      end
    end

    describe 'accessor methods' do
      let(:params) do
        {
          relationships: {
            space: { data: { guid: 'space-guid' } },
            domain: { data: { guid: 'domain-guid' } }
          }
        }
      end

      context 'space_guid' do
        it 'makes the guid accessible' do
          expect(subject).to be_valid
          expect(subject.space_guid).to eq('space-guid')
        end
      end

      context 'domain_guid' do
        it 'makes the guid accessible' do
          expect(subject).to be_valid
          expect(subject.domain_guid).to eq('domain-guid')
        end
      end
    end
  end
end
