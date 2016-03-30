require 'spec_helper'
require 'messages/base_message'

module VCAP::CloudController
  describe BaseMessage do
    describe '#requested?' do
      it 'returns true if the key was requested, false otherwise' do
        FakeClass = Class.new(BaseMessage) do
          def allowed_keys
            []
          end
        end

        message = FakeClass.new({ requested: 'thing' })

        expect(message.requested?(:requested)).to be_truthy
        expect(message.requested?(:notrequested)).to be_falsey
      end
    end

    describe '#audit_hash' do
      class AuditMessage < BaseMessage
        attr_accessor :field1, :field2

        def allowed_keys
          [:field1, :field2]
        end
      end

      it 'returns only requested keys in a json object' do
        message  = AuditMessage.new({ field1: 'value1' })
        response = message.audit_hash
        expect(response).to eq({ 'field1' => 'value1' })
      end

      it 'recursively includes keys' do
        message  = AuditMessage.new({ field1: 'value1', field2: { 'subfield' => 'subfield' } })
        response = message.audit_hash
        expect(response).to eq({ 'field1' => 'value1', 'field2' => { 'subfield' => 'subfield' } })
      end

      it 'excludes keys' do
        message  = AuditMessage.new({ field1: 'value1', field2: { 'subfield' => 'subfield' } })
        response = message.audit_hash(exclude: [:field2])
        expect(response).to eq({ 'field1' => 'value1' })
      end
    end

    describe '#to_param_hash' do
      ParamsClass = Class.new(BaseMessage) do
        attr_accessor :array_field, :num_field, :string_field, :nil_field

        def allowed_keys
          [:array_field, :num_field, :string_field, :nil_field]
        end
      end

      let(:opts) do
        {
            array_field:  ['st ate1', 'sta,te2'],
            num_field:    1.2,
            string_field: 'stringval&',
            nil_field:    nil
        }
      end

      it 'returns query param hash with escaped commas in array members' do
        expected_params = {
          array_field:  'st ate1,sta%2Cte2',
          num_field:    1.2,
          string_field: 'stringval&',
          nil_field:    nil,
        }
        expect(ParamsClass.new(opts).to_param_hash).to eq(expected_params)
      end

      it 'does not return params that are not requested during initialization' do
        opts.delete(:nil_field)
        expected_params = {
          array_field:  'st ate1,sta%2Cte2',
          num_field:    1.2,
          string_field: 'stringval&',
        }
        expect(ParamsClass.new(opts).to_param_hash).to eq(expected_params)
      end

      it 'can exclude params' do
        expected_params = {
          array_field:  'st ate1,sta%2Cte2',
          string_field: 'stringval&',
          nil_field:    nil,
        }
        expect(ParamsClass.new(opts).to_param_hash({ exclude: [:num_field] })).to eq(expected_params)
      end
    end

    describe '.to_array!' do
      let(:escaped_comma) { '%2C' }
      let(:params) do
        {
            array_field:                     'state1,state2',
            array_with_comma_in_value_field: "st ate1,sta#{escaped_comma}te2",
            array_with_nil_field:            'state1,state2,',
            num_field:                       1.2,
            string_field:                    'stringval&',
            nil_field:                       nil
        }
      end

      it 'separates on commas' do
        expect(BaseMessage.to_array!(params, :array_field)).to eq(['state1', 'state2'])
      end

      it 'url query decodes individual array values' do
        expect(BaseMessage.to_array!(params, :array_with_comma_in_value_field)).to eq(['st ate1', 'sta,te2'])
      end

      it 'handles nil array values' do
        expect(BaseMessage.to_array!(params, :array_with_nil_field)).to eq(['state1', 'state2'])
      end

      it 'handles single numeric values' do
        expect(BaseMessage.to_array!(params, :num_field)).to eq(['1.2'])
      end

      it 'handles single string values' do
        expect(BaseMessage.to_array!(params, :string_field)).to eq(['stringval&'])
      end

      it 'handles single nil values' do
        expect(BaseMessage.to_array!(params, :nil_field)).to eq(nil)
      end
    end

    describe 'additional keys validation' do
      let(:fake_class) do
        Class.new(BaseMessage) do
          validates_with VCAP::CloudController::BaseMessage::NoAdditionalKeysValidator

          def allowed_keys
            [:allowed]
          end

          def allowed=(_)
          end
        end
      end

      it 'is valid with an allowed message' do
        message = fake_class.new({ allowed: 'something' })

        expect(message).to be_valid
      end

      it 'is NOT valid with not allowed keys in the message' do
        message = fake_class.new({ notallowed: 'something', extra: 'stuff' })

        expect(message).to be_invalid
        expect(message.errors.full_messages[0]).to include("Unknown field(s): 'notallowed', 'extra'")
      end
    end

    describe 'additional params validation' do
      let(:fake_class) do
        Class.new(BaseMessage) do
          validates_with VCAP::CloudController::BaseMessage::NoAdditionalParamsValidator

          def allowed_keys
            [:allowed]
          end

          def allowed=(_)
          end
        end
      end

      it 'is valid with an allowed message' do
        message = fake_class.new({ allowed: 'something' })

        expect(message).to be_valid
      end

      it 'is NOT valid with not allowed keys in the message' do
        message = fake_class.new({ notallowed: 'something', extra: 'stuff' })

        expect(message).to be_invalid
        expect(message.errors.full_messages[0]).to include("Unknown query parameter(s): 'notallowed', 'extra'")
      end
    end
  end
end
