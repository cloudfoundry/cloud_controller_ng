require 'spec_helper'
require 'messages/base_message'

module VCAP::CloudController
  RSpec.describe BaseMessage do
    describe '.initialize' do
      let(:fake_class) do
        Class.new(BaseMessage) do
          register_allowed_keys []
        end
      end

      it 'symbolizes keys' do
        message = fake_class.new({ 'foo' => 'bar' })
        expect(message.requested?(:foo)).to be_truthy
      end

      it 'does not mutate the params for initialization' do
        params = { 'foo' => 'bar' }
        fake_class.new(params)
        expect(params['foo']).to eq('bar')
        expect(params).not_to have_key(:foo)
      end
    end

    describe '#requested?' do
      it 'returns true if the key was requested, false otherwise' do
        FakeClass = Class.new(BaseMessage) do
          register_allowed_keys []
        end

        message = FakeClass.new({ requested: 'thing' })

        expect(message.requested?(:requested)).to be_truthy
        expect(message.requested?(:notrequested)).to be_falsey
      end
    end

    describe '#audit_hash' do
      class AuditMessage < BaseMessage
        register_allowed_keys [:field1, :field2]
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
      class ParamsClass < BaseMessage
        register_allowed_keys [:array_field, :num_field, :string_field, :nil_field, :fields_field]
      end

      let(:opts) do
        {
          array_field: ['st ate1', 'sta,te2'],
          num_field: 1.2,
          string_field: 'stringval&',
          nil_field: nil
        }
      end

      it 'returns query param hash with escaped commas in array members' do
        expected_params = {
          array_field: 'st ate1,sta%2Cte2',
          num_field: 1.2,
          string_field: 'stringval&',
          nil_field: nil,
        }
        expect(ParamsClass.new(opts).to_param_hash).to eq(expected_params)
      end

      it 'does not return params that are not requested during initialization' do
        opts.delete(:nil_field)
        expected_params = {
          array_field: 'st ate1,sta%2Cte2',
          num_field: 1.2,
          string_field: 'stringval&',
        }
        expect(ParamsClass.new(opts).to_param_hash).to eq(expected_params)
      end

      it 'can exclude params' do
        expected_params = {
          array_field: 'st ate1,sta%2Cte2',
          string_field: 'stringval&',
          nil_field: nil,
        }
        expect(ParamsClass.new(opts).to_param_hash(exclude: [:num_field])).to eq(expected_params)
      end

      context 'when using fields' do
        let(:opts) do
          {
            fields_field: { foo: %w(bar baz), quz: %w(lala gaga) },
          }
        end

        it 'correctly formats the specified field' do
          expected_params = {
            'fields_field[foo]': 'bar,baz',
            'fields_field[quz]': 'lala,gaga',
          }
          expect(ParamsClass.new(opts).to_param_hash(fields: [:fields_field])).to eq(expected_params)
        end
      end
    end

    describe '.to_array!' do
      let(:escaped_comma) { '%2C' }
      let(:params) do
        {
          array_field: 'state1,state2',
          array_with_comma_in_value_field: "st ate1,sta#{escaped_comma}te2",
          array_with_plus: 'state+state2',
          array_with_empty_field: 'state1,state2,',
          num_field: 1.2,
          string_field: 'stringval&',
          nil_field: nil,
          empty_field: '',
          hash_not_array: { pi: 3.141592653589792 }
        }
      end

      it 'separates on commas' do
        expect(BaseMessage.to_array!(params, :array_field)).to eq(['state1', 'state2'])
      end

      it 'url query decodes individual array values' do
        expect(BaseMessage.to_array!(params, :array_with_comma_in_value_field)).to eq(['st ate1', 'sta,te2'])
      end

      it 'handles plus signs' do
        expect(BaseMessage.to_array!(params, :array_with_plus)).to eq(['state+state2'])
      end

      it 'handles nil array values' do
        expect(BaseMessage.to_array!(params, :array_with_empty_field)).to eq(['state1', 'state2', ''])
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

      it 'handles empty values' do
        expect(BaseMessage.to_array!(params, :empty_field)).to eq([''])
      end

      it "doesn't try to convert a hash to an array" do
        expect(BaseMessage.to_array!(params, :hash_not_array)).to eq(nil)
      end
    end

    describe 'additional keys validation' do
      let(:fake_class) do
        Class.new(BaseMessage) do
          register_allowed_keys [:allowed]
          validates_with VCAP::CloudController::BaseMessage::NoAdditionalKeysValidator
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
          register_allowed_keys [:allowed, :other_allowed]
          validates_with VCAP::CloudController::BaseMessage::NoAdditionalParamsValidator
        end
      end

      it 'is valid with an allowed BaseMessage' do
        message = fake_class.new({ allowed: 'something' })

        expect(message).to be_valid
      end

      it 'is NOT valid with not allowed keys in the BaseMessage' do
        message = fake_class.new({ notallowed: 'something', extra: 'stuff' })

        expect(message).to be_invalid
        expect(message.errors.full_messages[0]).to include("Unknown query parameter(s): 'notallowed', 'extra'. Valid parameters are: 'allowed', 'other_allowed'")
      end
    end

    describe 'include param validation' do
      let(:fake_class) do
        Class.new(BaseMessage) do
          register_allowed_keys [:include]
          validates_with VCAP::CloudController::BaseMessage::IncludeParamValidator, valid_values: ['foo', 'bar']
        end
      end

      it 'is valid with an allowed include value' do
        message = fake_class.new({ include: ['bar'] })

        expect(message).to be_valid
      end

      it 'is NOT valid with not allowed include value' do
        message = fake_class.new({ include: ['stuff'] })

        expect(message).to be_invalid
        expect(message.errors.full_messages[0]).to include("Invalid included resource: 'stuff'. Valid included resources are: 'foo', 'bar'")
      end
    end

    describe 'lifecycle type param validation' do
      let(:fake_class) do
        Class.new(BaseMessage) do
          register_allowed_keys [:lifecycle_type]
          validates_with VCAP::CloudController::BaseMessage::LifecycleTypeParamValidator
        end
      end

      it 'is valid with an allowed lifecycle_type value' do
        message = fake_class.new({ lifecycle_type: 'docker' })

        expect(message).to be_valid
      end

      it 'is NOT valid with not allowed lifecycle_type value' do
        message = fake_class.new({ lifecycle_type: 'stuff' })

        expect(message).to be_invalid
        expect(message.errors.full_messages[0]).to include("Invalid lifecycle_type: 'stuff'")
      end
    end

    describe '.from_params' do
      FakeFieldsClass = Class.new(BaseMessage) do
        register_allowed_keys [:name, :names]
      end

      it 'creates an object with the hash keys as instance variables' do
        instance = FakeFieldsClass.from_params({ 'name' => 'aname' }, [])
        expect(instance.name).to eq('aname')

        instance = FakeFieldsClass.from_params({ name: 'aname' }, [])
        expect(instance.name).to eq('aname')
      end

      it 'converts comma-separated values to arrays when specified' do
        instance = FakeFieldsClass.from_params({ 'names' => 'a-name,another-name' }, %w(names))
        expect(instance.names).to contain_exactly('a-name', 'another-name')
      end

      it 'converts comma-separated hash values to arrays when specified' do
        instance = FakeFieldsClass.from_params({ 'names' => { 'space' => 'a-name,another-name' } }, [], fields: %w(names))
        expect(instance.names).to match({ space: ['a-name', 'another-name'] })
      end

      context 'when fields parameters are invalid' do
        it 'skips the conversion' do
          instance = FakeFieldsClass.from_params({ 'names' => 'foo' }, [], fields: %w(name names))
          expect(instance.name).to be_nil
          expect(instance.names).to eq('foo')
        end
      end
    end
  end
end
