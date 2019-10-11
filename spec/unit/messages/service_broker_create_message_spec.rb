require 'lightweight_spec_helper'
require 'active_model'
require 'rspec/collection_matchers'
require 'messages/service_broker_create_message'
require 'messages/validators/url_validator'
require 'messages/validators/authentication_validator'

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
      let(:message) { ServiceBrokerCreateMessage.new(request_body) }

      context 'when all values are correct' do
        let(:request_body) { valid_body }

        it 'is valid' do
          expect(message).to be_valid
        end
      end

      context 'when unexpected keys are requested' do
        let(:request_body) do
          valid_body.merge(surprise_key: 'boo')
        end

        it 'is not valid' do
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
            expect(message).not_to be_valid
            expect(message.errors_on(:name)).to include('must be a string')
          end
        end

        context 'when name is empty string' do
          let(:request_body) do
            valid_body.merge(name: '')
          end

          it 'is not valid' do
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
            expect(message).not_to be_valid
            expect(message.errors_on(:url)).to include('must be a string')
          end
        end

        context 'when url is not valid' do
          let(:request_body) do
            body = valid_body
            body['url'] = 'http://the-best-broker.com'
            body
          end

          before do
            allow_any_instance_of(VCAP::CloudController::Validators::UrlValidator).to receive(:validate) do |_, record|
              record.errors.add(:url, 'this url is not valid!')
            end
          end

          it 'is not valid' do
            expect(message).not_to be_valid
            expect(message.errors_on(:url)).to include('this url is not valid!')
          end
        end
      end

      context 'authentication' do
        context 'when authentication is not a hash' do
          let(:request_body) do
            valid_body.except(:authentication)
          end

          it 'is not valid' do
            expect(message).not_to be_valid
            expect(message.errors_on(:authentication)).to include('must be a hash')
          end
        end

        context 'when authentication is not valid' do
          let(:request_body) do
            valid_body
          end

          before do
            allow_any_instance_of(VCAP::CloudController::Validators::AuthenticationValidator).to receive(:validate) do |_, record|
              record.errors.add(:authentication, 'this authentication is not valid!')
            end
          end

          it 'is not valid' do
            expect(message).not_to be_valid
            expect(message.errors_on(:authentication)).to include('this authentication is not valid!')
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
        message = subject.new(valid_body)
        expect(
          HashUtils.dig(message.audit_hash, 'authentication', 'credentials', 'password')
        ).to eq('[PRIVATE DATA HIDDEN]')
      end
    end
  end
end
