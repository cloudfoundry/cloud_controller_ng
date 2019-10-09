require 'lightweight_spec_helper'
require 'active_model'
require 'rspec/collection_matchers'
require 'messages/service_broker_create_message'

module VCAP::CloudController
  RSpec.describe ServiceBrokerCreateMessage do
    subject { ServiceBrokerCreateMessage }

    let(:valid_body) do
      {
        name: 'best-broker',
        url: 'https://the-best-broker.url',
        authentication: {
          type: 'basic',
          credentials: {
            username: 'user',
            password: 'pass',
          }
        },
      }
    end

    describe 'validations' do
      context 'when all values are correct' do
        let(:request_body) { valid_body }

        it 'is valid' do
          message = ServiceBrokerCreateMessage.new(request_body)
          expect(message).to be_valid
        end
      end

      context 'when all values are correct and the scheme is http' do
        let(:request_body) do
          body = valid_body
          body['url'] = 'http://the-best-broker.url'
          body
        end

        it 'is valid' do
          message = ServiceBrokerCreateMessage.new(request_body)
          expect(message).to be_valid
        end
      end

      context 'when unexpected keys are requested' do
        let(:request_body) do
          valid_body.merge(surprise_key: 'boo')
        end

        it 'is not valid' do
          message = ServiceBrokerCreateMessage.new(request_body)

          expect(message).not_to be_valid
          expect(message.errors[:base]).to include("Unknown field(s): 'surprise_key'")
        end
      end

      context 'name' do
        context 'when name is not a string' do
          let(:request_body) do
            valid_body.merge(name: true)
          end

          it 'is not valid' do
            message = ServiceBrokerCreateMessage.new(request_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:name)).to include('must be a string')
          end
        end

        context 'when name is empty string' do
          let(:request_body) do
            valid_body.merge(name: '')
          end

          it 'is not valid' do
            message = ServiceBrokerCreateMessage.new(request_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:name)).to include('must not be empty string')
          end
        end
      end

      context 'url' do
        context 'when url is not a string' do
          let(:request_body) do
            valid_body.merge(url: true)
          end

          it 'is not valid' do
            message = ServiceBrokerCreateMessage.new(request_body)
            expect(message).not_to be_valid
            expect(message.errors_on(:url)).to include('must be a string')
          end
        end

        context 'when url is not valid' do
          let(:request_body) do
            valid_body.merge(url: 'lol.com')
          end

          it 'is not valid' do
            message = ServiceBrokerCreateMessage.new(request_body)
            expect(message).not_to be_valid
            expect(message.errors_on(:url)).to include('must be a valid url')
          end
        end

        context 'when url has wrong scheme' do
          let(:request_body) do
            valid_body.merge(url: 'ftp://the-best-broker.url')
          end

          it 'is not valid' do
            message = ServiceBrokerCreateMessage.new(request_body)
            expect(message).not_to be_valid
            expect(message.errors_on(:url)).to include('must be a valid url')
          end
        end

        context 'when url contains a basic auth user' do
          let(:request_body) do
            valid_body.merge(url: 'http://username@lol.com')
          end

          it 'is not valid' do
            message = ServiceBrokerCreateMessage.new(request_body)
            expect(message).not_to be_valid
            expect(message.errors_on(:url)).to include('must not contain authentication')
          end
        end

        context 'when url contains a basic auth password' do
          let(:request_body) do
            valid_body.merge(url: 'http://username:password@lol.com')
          end

          it 'is not valid' do
            message = ServiceBrokerCreateMessage.new(request_body)
            expect(message).not_to be_valid
            expect(message.errors_on(:url)).to include('must not contain authentication')
          end
        end
      end

      context 'authentication' do
        context 'when authentication is not a hash' do
          let(:request_body) do
            valid_body.except(:authentication)
          end

          it 'is not valid' do
            message = ServiceBrokerCreateMessage.new(request_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:authentication)).to include('must be a hash')
          end
        end

        context 'when authentication.type is invalid' do
          let(:request_body) do
            valid_body.merge(authentication: {
              type: 'oopsie'
            })
          end

          it 'is not valid' do
            message = ServiceBrokerCreateMessage.new(request_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:authentication_type)).to include('authentication.type must be one of ["basic"]')
          end
        end

        context 'when username and password are missing from credentials' do
          let(:request_body) do
            valid_body.merge(authentication: {
              type: 'basic',
              data: {},
            })
          end

          it 'is not valid' do
            message = ServiceBrokerCreateMessage.new(request_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:authentication_credentials)).to include(/Field\(s\) \["username", "password"\] must be valid/)
          end
        end

        context 'when data is missing from authentication' do
          let(:request_body) do
            valid_body.merge(authentication: {
              type: 'basic'
            })
          end

          it 'is not valid' do
            message = ServiceBrokerCreateMessage.new(request_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:authentication_credentials)).to include('must be a hash')
          end
        end

        context 'when authentication has extra fields' do
          let(:request_body) do
            valid_body.merge(authentication: {
              extra: 'value',
              type: 'basic',
            })
          end

          it 'is not valid' do
            message = ServiceBrokerCreateMessage.new(request_body)

            expect(message).not_to be_valid
            expect(message.errors_on(:authentication)).to include("Unknown field(s): 'extra'")
          end
        end
      end

      context 'space guid relationship' do
        subject { ServiceBrokerCreateMessage.new(request_body) }

        context 'when relationships are structured properly' do
          let(:request_body) { valid_body.merge(relationships: { space: { data: { guid: 'space-guid-here' } } }) }

          it 'is valid' do
            expect(subject).to be_valid
            expect(subject.space_guid).to eq('space-guid-here')
          end
        end

        context 'when relationships is not a hash' do
          let(:request_body) { valid_body.merge(relationships: 42) }

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors_on(:relationships)).to include("'relationships' is not a hash")
          end
        end

        context 'when relationships does not have a valid structure' do
          let(:request_body) { valid_body.merge(relationships: { oopsie: 'not valid', other: 'invalid' }) }

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors_on(:relationships)).to include("Unknown field(s): 'oopsie', 'other'")
            expect(subject.errors_on(:relationships)).to include("Space can't be blank")
            expect(subject.errors_on(:relationships)).to include('Space must be structured like this: "space: {"data": {"guid": "valid-guid"}}"')
          end
        end

        context 'when relationships.space is not a hash' do
          let(:request_body) { valid_body.merge(relationships: { space: 42 }) }

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors_on(:relationships)).to include('Space must be structured like this: "space: {"data": {"guid": "valid-guid"}}"')
          end
        end

        context 'when relationships.space does not have a valid structure' do
          let(:request_body) { valid_body.merge(relationships: { space: { oopsie: 'not valid', other: 'invalid' } }) }

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors_on(:relationships)).to include('Space must be structured like this: "space: {"data": {"guid": "valid-guid"}}"')
          end
        end

        context 'when relationships.space.data is not a hash' do
          let(:request_body) { valid_body.merge(relationships: { space: { data: 42 } }) }

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors_on(:relationships)).to include('Space must be structured like this: "space: {"data": {"guid": "valid-guid"}}"')
          end
        end

        context 'when relationships.space.data does not have a valid structure' do
          let(:request_body) { valid_body.merge(relationships: { space: { data: { oopsie: 'not valid', other: 'invalid' } } }) }

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors_on(:relationships)).to include('Space must be structured like this: "space: {"data": {"guid": "valid-guid"}}"')
          end
        end

        context 'when relationships.space.data.guid is not a string' do
          let(:request_body) { valid_body.merge(relationships: { space: { data: { guid: 42 } } }) }

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors_on(:relationships)).to include('Space guid must be a string')
            expect(subject.errors_on(:relationships)).to include('Space guid must be between 1 and 200 characters')
          end
        end
      end
    end

    describe '#audit_hash' do
      it 'redacts the password' do
        message = ServiceBrokerCreateMessage.new(valid_body)

        expect(message.audit_hash).to eq({
          name: 'best-broker',
          url: 'https://the-best-broker.url',
          authentication: {
            type: 'basic',
            credentials: {
              username: 'user',
              password: '[PRIVATE DATA HIDDEN]',
            }
          },
        }.with_indifferent_access)
      end
    end
  end
end
