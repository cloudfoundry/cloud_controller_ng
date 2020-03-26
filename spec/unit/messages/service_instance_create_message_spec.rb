require 'lightweight_spec_helper'
require 'messages/service_instance_create_message'

module VCAP::CloudController
  RSpec.describe ServiceInstanceCreateMessage do
    let(:body) do
      {
        type: 'user-provided',
        name: 'my-service-instance',
        credentials: {
          foo: 'bar',
          baz: 'qux'
        },
        syslog_drain_url: 'https://drain.com/foo',
        route_service_url: 'https://route.com/bar',
        tags: %w(foo bar baz),
        relationships: {
          space: {
            data: {
              guid: 'space-guid'
            }
          }
        },
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

    let(:message) { ServiceInstanceCreateMessage.new(body) }

    it 'accepts the allowed keys' do
      expect(message).to be_valid
      expect(message.requested?(:type)).to be_truthy
      expect(message.requested?(:name)).to be_truthy
      expect(message.requested?(:relationships)).to be_truthy
      expect(message.requested?(:credentials)).to be_truthy
      expect(message.requested?(:syslog_drain_url)).to be_truthy
      expect(message.requested?(:route_service_url)).to be_truthy
      expect(message.requested?(:tags)).to be_truthy
    end

    it 'builds the right message' do
      expect(message.type).to eq('user-provided')
      expect(message.name).to eq('my-service-instance')
      expect(message.space_guid).to eq('space-guid')
      expect(message.metadata[:labels]).to eq({ potato: 'mashed' })
      expect(message.metadata[:annotations]).to eq({ cheese: 'bono' })
      expect(message.credentials).to match({ foo: 'bar', baz: 'qux' })
      expect(message.syslog_drain_url).to eq('https://drain.com/foo')
      expect(message.route_service_url).to eq('https://route.com/bar')
      expect(message.tags).to contain_exactly('foo', 'bar', 'baz')
    end

    it 'accepts the minimal request' do
      message = ServiceInstanceCreateMessage.new({
        type: 'user-provided',
        name: 'my-service-instance',
        relationships: {
          space: {
            data: {
              guid: 'space-guid'
            }
          }
        }
      })
      expect(message).to be_valid
    end

    describe 'validations' do
      it 'is invalid when there are unknown keys' do
        body['bogus'] = 'field'

        expect(message).to_not be_valid
        expect(message.errors.full_messages).to include("Unknown field(s): 'bogus'")
      end

      describe 'type' do
        it 'accepts the valid types' do
          %w{user-provided}.each do |t|
            body[:type] = t
            message = ServiceInstanceCreateMessage.new(body)
            expect(message).to be_valid
          end
        end

        it 'is invalid when is not set' do
          message = ServiceInstanceCreateMessage.new({})
          expect(message).to_not be_valid
          expect(message.errors.full_messages).to include("Type must be one of 'managed', 'user-provided'")
        end

        it 'is invalid when is not one of the valid types' do
          message = ServiceInstanceCreateMessage.new({ 'type' => 'banana' })
          expect(message).to_not be_valid
          expect(message.errors.full_messages).to include("Type must be one of 'managed', 'user-provided'")
        end
      end

      describe 'name' do
        it 'must be present' do
          body.delete(:name)

          message = ServiceInstanceCreateMessage.new(body)
          expect(message).not_to be_valid
          expect(message.errors[:name]).to include("can't be blank")
        end

        it 'must be a string' do
          body[:name] = 12

          message = ServiceInstanceCreateMessage.new(body)
          expect(message).not_to be_valid
          expect(message.errors[:name]).to include('must be a string')
        end
      end

      describe 'metadata' do
        it 'is invalid when there are bogus metadata fields' do
          body.merge!({ "metadata": { "choppers": 3 } })
          expect(message).not_to be_valid
        end
      end

      describe 'relationships' do
        it 'is invalid when there is no space relationship' do
          body['relationships'] = { 'foo': {} }

          expect(message).to_not be_valid
          expect(message.errors.full_messages).to include("Relationships Space can't be blank")
        end

        it 'is invalid when there are unknown relationships' do
          body['relationships'] = { 'service-offering' => { 'data' => { 'guid' => 'offering-guid' } } }

          expect(message).to_not be_valid
          expect(message.errors.full_messages).to include("Relationships Unknown field(s): 'service-offering'")
        end
      end

      describe 'credentials' do
        it 'must be a hash if present' do
          body[:credentials] = 42

          message = ServiceInstanceCreateMessage.new(body)
          expect(message).not_to be_valid
          expect(message.errors[:credentials]).to include('must be an object')
        end
      end

      describe 'syslog_drain_url' do
        it 'must be a URI if present' do
          body[:syslog_drain_url] = 42

          message = ServiceInstanceCreateMessage.new(body)
          expect(message).not_to be_valid
          expect(message.errors[:syslog_drain_url]).to include('must be a valid URI')
        end
      end

      describe 'route_service_url' do
        it 'must be a URI if present' do
          body[:route_service_url] = 42

          message = ServiceInstanceCreateMessage.new(body)
          expect(message).not_to be_valid
          expect(message.errors[:route_service_url]).to include('must be a valid URI')
        end

        it 'must use https' do
          body[:route_service_url] = 'http://route.com/bar'

          message = ServiceInstanceCreateMessage.new(body)
          expect(message).not_to be_valid
          expect(message.errors[:route_service_url]).to include('must be https')
        end
      end

      describe 'tags' do
        it 'must be an array if present' do
          body[:tags] = 42

          message = ServiceInstanceCreateMessage.new(body)
          expect(message).not_to be_valid
          expect(message.errors[:tags]).to include('must be an array')
        end

        it 'must be contain strings' do
          body[:tags] = ['foo', {}, 4]

          message = ServiceInstanceCreateMessage.new(body)
          expect(message).not_to be_valid
          expect(message.errors[:tags]).to include('must be a list of strings')
        end
      end
    end

    describe '.audit_hash' do
      it 'produces a redacted audit hash' do
        expected = body.dup.tap { |b| b[:credentials] = '[PRIVATE DATA HIDDEN]' }
        expect(message.audit_hash).to match(expected.with_indifferent_access)
      end
    end
  end
end
