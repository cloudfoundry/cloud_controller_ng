require 'spec_helper'
require 'lightweight_spec_helper'
require 'messages/validators'
require 'messages/base_message'
require 'messages/empty_lifecycle_data_message'
require 'messages/buildpack_lifecycle_data_message'
require 'cloud_controller/diego/lifecycles/app_docker_lifecycle'
require 'cloud_controller/diego/lifecycles/app_buildpack_lifecycle'
require 'cloud_controller/diego/lifecycles/lifecycles'
require 'rspec/collection_matchers'

module VCAP::CloudController::Validators
  RSpec.describe 'Validators' do
    let(:fake_class) do
      Class.new do
        include ActiveModel::Model
        include VCAP::CloudController::Validators

        attr_accessor :field

        def self.model_name
          ActiveModel::Name.new(self, nil, 'fake class')
        end
      end
    end

    describe 'validator extending StandaloneValidator' do
      describe '.validate_each' do
        it 'calls through to the instance method so it can be easily used outside of Active Models' do
          my_validator = Class.new(ActiveModel::EachValidator) do
            extend StandaloneValidator

            def validate_each(record, attr_name, value)
              "hello #{record} #{attr_name} #{value}"
            end
          end

          expect(my_validator.validate_each(1, 2, 3)).to eq('hello 1 2 3')
        end
      end
    end

    describe 'ArrayValidator' do
      let(:array_class) do
        Class.new(fake_class) do
          validates :field, array: true
        end
      end

      it 'adds an error if the field is not an array' do
        fake_class = array_class.new field: 'not array'
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:field]).to include 'must be an array'
      end

      it 'does not add an error if the field is an array' do
        fake_class = array_class.new field: %w[an array]
        expect(fake_class).to be_valid
      end
    end

    describe 'StringValidator' do
      let(:string_class) do
        Class.new(fake_class) do
          validates :field, string: true
        end
      end

      it 'adds an error if the field is not a string' do
        fake_class = string_class.new field: {}
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:field]).to include 'must be a string'
      end

      it 'does not add an error if the field is a string' do
        fake_class = string_class.new field: 'hi i am string'
        expect(fake_class).to be_valid
      end
    end

    describe 'BooleanValidator' do
      let(:boolean_class) do
        Class.new(fake_class) do
          validates :field, boolean: true
        end
      end

      it 'adds an error if the field is not a boolean' do
        instance = boolean_class.new field: {}
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'must be a boolean'
      end

      it 'does not add an error if the field is a boolean' do
        instance = boolean_class.new field: true
        expect(instance).to be_valid

        instance = boolean_class.new field: false
        expect(instance).to be_valid
      end
    end

    describe 'BooleanStringValidator' do
      let(:boolean_class) do
        Class.new(fake_class) do
          validates :field, boolean_string: true
        end
      end

      it 'adds an error if the field is not a boolean string' do
        instance = boolean_class.new field: 'snarf'
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include "must be 'true' or 'false'"
      end

      it 'does not add an error if the field is a boolean string' do
        instance = boolean_class.new field: 'true'
        expect(instance).to be_valid

        instance = boolean_class.new field: 'false'
        expect(instance).to be_valid
      end
    end

    describe 'HashValidator' do
      let(:hash_class) do
        Class.new(fake_class) do
          validates :field, hash: true
        end
      end

      it 'adds an error if the field is not an object' do
        fake_class = hash_class.new field: 'not an object'
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:field]).to include 'must be an object'
      end

      it 'does not add an error if the field is a hash' do
        fake_class = hash_class.new field: { totes: 'hash' }
        expect(fake_class).to be_valid
      end
    end

    describe 'GuidValidator' do
      let(:guid_class) do
        Class.new(fake_class) do
          validates :field, guid: true
        end
      end

      it 'adds an error if the field is not a string' do
        fake_class = guid_class.new field: 4
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:field]).to include 'must be a string'
      end

      it 'adds an error if the field is nil' do
        fake_class = guid_class.new field: nil
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:field]).to include 'must be a string'
      end

      it 'adds an error if the field is too long' do
        fake_class = guid_class.new field: 'a' * 201
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:field]).to include 'must be between 1 and 200 characters'
      end

      it 'adds an error if the field is empty' do
        fake_class = guid_class.new field: ''
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:field]).to include 'must be between 1 and 200 characters'
      end

      it 'does not add an error if the field is a guid' do
        fake_class = guid_class.new field: 'such-a-guid-1234'
        expect(fake_class).to be_valid
      end
    end

    describe 'UriValidator' do
      let(:uri_class) do
        Class.new(fake_class) do
          validates :field, uri: true
        end
      end

      it 'adds an error if the field is not a URI' do
        fake_class = uri_class.new field: 'not a URI'
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:field]).to include 'must be a valid URI'
      end

      it 'does not add an error if the field is a URI' do
        fake_class = uri_class.new field: 'http://www.purple.com'
        expect(fake_class).to be_valid
      end
    end

    describe 'EnvironmentVariablesValidator' do
      let(:environment_variables_class) do
        Class.new(fake_class) do
          validates :field, environment_variables: true
        end
      end

      it 'does not add an error if the environment variables are correct' do
        fake_class = environment_variables_class.new field: { VARIABLE: 'amazing' }
        expect(fake_class).to be_valid
      end

      it 'validates that the input is a hash' do
        fake_class = environment_variables_class.new field: 4
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:field]).to include 'must be an object'
      end

      it 'does not allow variables that start with VCAP_' do
        fake_class = environment_variables_class.new field: { VCAP_BANANA: 'woo' }
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:field]).to include 'cannot start with VCAP_'
      end

      it 'does not allow variables that start with vcap_' do
        fake_class = environment_variables_class.new field: { vcap_donkey: 'hee-haw' }
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:field]).to include 'cannot start with VCAP_'
      end

      it 'does not allow variables that start with VMC_' do
        fake_class = environment_variables_class.new field: { VMC_BANANA: 'woo' }
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:field]).to include 'cannot start with VMC_'
      end

      it 'does not allow variables that start with vmc_' do
        fake_class = environment_variables_class.new field: { vmc_donkey: 'hee-haw' }
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:field]).to include 'cannot start with VMC_'
      end

      it 'does not allow variables that are PORT' do
        fake_class = environment_variables_class.new field: { PORT: 'el lunes nos ponemos camisetas naranjas' }
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:field]).to include 'cannot set PORT'
      end

      it 'does not allow variables that are port' do
        fake_class = environment_variables_class.new field: { port: 'el lunes nos ponemos camisetas naranjas' }
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:field]).to include 'cannot set PORT'
      end

      it 'does not allow variables with zero key length' do
        fake_class = environment_variables_class.new field: { '': 'el lunes nos ponemos camisetas naranjas' }
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:field]).to include 'key must be a minimum length of 1'
      end

      it 'does not allow variables with non-string keys' do
        fake_class = environment_variables_class.new field: { 1 => 'el lunes nos ponemos camisetas naranjas' }
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:field]).to include 'key must be a string'
      end
    end

    describe 'EnvironmentVariablesStringValuesValidator' do
      let(:environment_variables_class) do
        Class.new(fake_class) do
          validates :field, environment_variables_string_values: true
        end
      end

      it 'does not add an error if the environment variables are correct' do
        fake_class = environment_variables_class.new field: { VARIABLE: 'amazing' }
        expect(fake_class).to be_valid
      end

      it 'validates that the input is a hash' do
        fake_class = environment_variables_class.new field: 4
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:field]).to include 'must be an object'
      end

      it 'does not allow variables that start with VCAP_' do
        fake_class = environment_variables_class.new field: { VCAP_BANANA: 'woo' }
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:field]).to include 'cannot start with VCAP_'
      end

      it 'does not allow variables that start with vcap_' do
        fake_class = environment_variables_class.new field: { vcap_donkey: 'hee-haw' }
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:field]).to include 'cannot start with VCAP_'
      end

      it 'does not allow variables that start with VMC_' do
        fake_class = environment_variables_class.new field: { VMC_BANANA: 'woo' }
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:field]).to include 'cannot start with VMC_'
      end

      it 'does not allow variables that start with vmc_' do
        fake_class = environment_variables_class.new field: { vmc_donkey: 'hee-haw' }
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:field]).to include 'cannot start with VMC_'
      end

      it 'does not allow variables that are PORT' do
        fake_class = environment_variables_class.new field: { PORT: 'el lunes nos ponemos camisetas naranjas' }
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:field]).to include 'cannot set PORT'
      end

      it 'does not allow variables that are port' do
        fake_class = environment_variables_class.new field: { port: 'el lunes nos ponemos camisetas naranjas' }
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:field]).to include 'cannot set PORT'
      end

      it 'does not allow variables with zero key length' do
        fake_class = environment_variables_class.new field: { '': 'el lunes nos ponemos camisetas naranjas' }
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:field]).to include 'key must be a minimum length of 1'
      end

      it 'does not allow variables with non-string keys' do
        fake_class = environment_variables_class.new field: { 1 => 'el lunes nos ponemos camisetas naranjas' }
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:field]).to include 'key must be a string'
      end

      it 'does not allow variables with array values' do
        fake_class = environment_variables_class.new field: { fibonacci: [1, 1, 2, 3, 5, 8] }
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:base]).to eq ["Non-string value in environment variable for key 'fibonacci', value '[1,1,2,3,5,8]'"]
      end

      it 'does not allow variables with object values' do
        fake_class = environment_variables_class.new field: { obj: { wow: 'cool' } }
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:base]).to eq ["Non-string value in environment variable for key 'obj', value '{\"wow\":\"cool\"}'"]
      end
    end

    describe 'FieldsValidator' do
      let(:fields_class) do
        Class.new(fake_class) do
          validates :field, fields: { allowed: { 'space.organization' => ['name'] } }
        end
      end

      it 'rejects values that are not hashes' do
        fake_class = fields_class.new field: 'foo'
        expect(fake_class).not_to be_valid
        expect(fake_class.errors[:field]).to include 'must be an object'
      end

      context 'allowed keys' do
        let(:fields_class_multiple_keys) do
          Class.new(fake_class) do
            validates :field, fields: { allowed: { 'some.resource' => %w[fake-value-1 fake-value-2] } }
          end
        end

        it 'allows a multiple keys to be present' do
          fake_class = fields_class_multiple_keys.new field: { 'some.resource': %w[fake-value-2 fake-value-1] }
          expect(fake_class).to be_valid
        end

        it 'allows a subset of keys' do
          fake_class = fields_class_multiple_keys.new field: { 'some.resource': %w[fake-value-2] }
          expect(fake_class).to be_valid
        end

        it 'reject keys not in the list' do
          fake_class = fields_class_multiple_keys.new field: { 'some.resource': %w[fake-value-2 url] }
          expect(fake_class).not_to be_valid
          expect(fake_class.errors[:field]).to include "valid keys for 'some.resource' are: 'fake-value-1', 'fake-value-2'"
        end
      end

      context 'allowed resources' do
        let(:fields_class_multiple_resources) do
          Class.new(fake_class) do
            validates :field, fields: { allowed: { 'a.resource' => ['fake-value'], 'another.resource' => ['another-fake-value'] } }
          end
        end

        it 'allows a multiple resources to be present' do
          fake_class = fields_class_multiple_resources.new field: { 'a.resource': %w[fake-value], 'another.resource': %w[another-fake-value] }
          expect(fake_class).to be_valid
        end

        it 'allows a subset of the resources to be present' do
          fake_class = fields_class_multiple_resources.new field: { 'another.resource': %w[another-fake-value] }
          expect(fake_class).to be_valid
        end

        it 'rejects resources not specified' do
          fake_class = fields_class_multiple_resources.new field: { 'wrong.resource': %w[another-fake-value] }
          expect(fake_class).not_to be_valid
          expect(fake_class.errors[:field]).to include "[wrong.resource] valid resources are: 'a.resource', 'another.resource'"
        end
      end
    end

    describe 'HealthCheckValidator' do
      let(:health_check_class) do
        Class.new(fake_class) do
          attr_accessor :health_check_type, :health_check_http_endpoint

          validates_with HealthCheckValidator
        end
      end

      context 'when the healthcheck type is not "http"' do
        it 'correctly adds the health_check_type validation errors' do
          message = health_check_class.new({
                                             health_check_type: 'not-http',
                                             health_check_http_endpoint: 'a-great-uri'
                                           })

          expect(message).not_to be_valid
          expect(message.errors_on(:health_check_type)).to include('must be "http" to set a health check HTTP endpoint')
        end
      end
    end

    describe 'LifecycleValidator' do
      let(:lifecycle_class) do
        Class.new(fake_class) do
          attr_accessor :lifecycle

          validates_with LifecycleValidator

          def lifecycle_data
            lifecycle[:data] || lifecycle['data']
          end

          def lifecycle_type
            lifecycle[:type] || lifecycle['type']
          end
        end
      end

      context 'when the lifecycle type provided is invalid' do
        it 'adds lifecycle_type error message to the base class' do
          message = lifecycle_class.new({ lifecycle: { type: 'not valid', data: {} } })

          expect(message).not_to be_valid
          expect(message.errors_on(:lifecycle_type)).to include('is not included in the list: buildpack, docker, cnb')
        end
      end

      context 'when the lifecycle type is not provided' do
        it 'correctly adds the buildpack data message validation errors' do
          message = lifecycle_class.new({ lifecycle: { data: { buildpacks: [123] } } })

          expect(message).not_to be_valid
          expect(message.errors_on(:lifecycle)).to contain_exactly('Buildpacks can only contain strings')
        end
      end

      context 'when lifecycle type provided is buildpack' do
        context 'when the buildpack lifecycle data is invalid' do
          it 'correctly adds the buildpack data message validation errors' do
            message = lifecycle_class.new({ lifecycle: { type: 'buildpack', data: { buildpacks: [123] } } })

            expect(message).not_to be_valid
            expect(message.errors_on(:lifecycle)).to include('Buildpacks can only contain strings')
          end
        end
      end
    end

    describe 'DataValidator' do
      class DataMessage < VCAP::CloudController::BaseMessage
        register_allowed_keys [:data]
        validates_with DataValidator

        class Data < VCAP::CloudController::BaseMessage
          register_allowed_keys [:foo]

          validates :foo, numericality: true
        end
      end

      it "adds data's error message to the base class" do
        message = DataMessage.new({ data: { foo: 'not a number' } })
        expect(message).not_to be_valid
        expect(message.errors_on(:data)).to include('Foo is not a number')
      end

      it 'returns early when base class data is not an object' do
        message = DataMessage.new({ data: 'not an object' })
        expect(message).to be_valid
        expect(message.errors_on(:data)).to be_empty
      end
    end

    describe 'RelationshipValidator' do
      class RelationshipMessage < VCAP::CloudController::BaseMessage
        register_allowed_keys [:relationships]

        def relationships_message
          Relationships.new(relationships.deep_symbolize_keys)
        end

        validates_with RelationshipValidator

        class Relationships < VCAP::CloudController::BaseMessage
          register_allowed_keys [:foo]

          validates :foo, numericality: true
        end
      end

      it "adds relationships' error message to the base class" do
        message = RelationshipMessage.new({ relationships: { foo: 'not a number' } })
        expect(message).not_to be_valid
        expect(message.errors_on(:relationships)).to include('Foo is not a number')
      end

      it 'returns early when base class relationships is not an object' do
        message = RelationshipMessage.new({ relationships: 'not an object' })
        expect(message).not_to be_valid
        expect(message.errors_on(:relationships)).to include("'relationships' is not an object")
      end
    end

    describe 'ToOneRelationshipValidator' do
      let(:to_one_class) do
        Class.new(fake_class) do
          validates :field, to_one_relationship: true
        end
      end

      it 'ensures that the data has the correct structure' do
        bad_guid_key = to_one_class.new({ field: { data: { not_a_guid: '1234' } } })
        bad_guid_value = to_one_class.new({ field: { data: { guid: { woah: '1234' } } } })

        bad_data_key = to_one_class.new({ field: { not_data: '1234' } })
        bad_data_value = to_one_class.new({ field: { data: '1234' } })
        missing_data = to_one_class.new({ field: '1234' })

        valid = to_one_class.new(field: { data: { guid: '1234' } })

        expect(bad_guid_key).not_to be_valid
        expect(bad_guid_value).not_to be_valid
        expect(bad_data_key).not_to be_valid
        expect(bad_data_value).not_to be_valid
        expect(missing_data).not_to be_valid
        expect(valid).to be_valid
      end

      it 'allows for nil value in data' do
        valid = to_one_class.new(field: { data: nil })

        expect(valid).to be_valid
      end

      it 'adds an error if the field is not structured correctly' do
        invalid = to_one_class.new({ field: { data: { not_a_guid: 1234 } } })
        expect(invalid).not_to be_valid
        expect(invalid.errors[:field]).to include 'must be structured like this: "field: {"data": {"guid": "valid-guid"}}"'
      end
    end

    describe 'ToManyRelationshipValidator' do
      let(:to_many_class) do
        Class.new(fake_class) do
          validates :field, to_many_relationship: true
        end
      end

      it 'ensures that the data has the correct structure' do
        valid = to_many_class.new({ field: {
                                    data: [{ guid: '1234' }, { guid: '1234' }, { guid: '1234' }, { guid: '1234' }]
                                  } })
        invalid_one = to_many_class.new({ field: { data: { guid: '1234' } } })
        invalid_two = to_many_class.new({ field: { data: [{ guid: 1234 }, { guid: 1234 }] } })
        invalid_three = to_many_class.new({ field: [{ guid: '1234' }, { guid: '1234' }, { guid: '1234' }, { guid: '1234' }] })

        expect(valid).to be_valid
        expect(invalid_one).not_to be_valid
        expect(invalid_two).not_to be_valid
        expect(invalid_three).not_to be_valid
      end
    end

    describe 'OrgVisibilityValidator' do
      let(:visibility_class) do
        Class.new(fake_class) do
          validates :field, org_visibility: true
        end
      end

      it 'ensures that it has correct structure' do
        valid = visibility_class.new({ field: [{ guid: '1234' }, { guid: '1234' }, { guid: '1234' }, { guid: '1234' }] })
        invalid_one = visibility_class.new({ field: { guid: '1234' } })
        invalid_two = visibility_class.new({ field: [{ guid: 1234 }, { guid: 1234 }] })
        invalid_three = visibility_class.new({ field: ['123'] })

        expect(valid).to be_valid
        expect(invalid_one).not_to be_valid
        expect(invalid_two).not_to be_valid
        expect(invalid_three).not_to be_valid
      end
    end

    describe 'TimestampValidator' do
      let(:timestamp_class) do
        Class.new(fake_class) do
          validates :field, timestamp: true
        end
      end

      it 'requires a hash or an array of timestamps' do
        message = timestamp_class.new({ field: 47 })
        expect(message).not_to be_valid
        expect(message.errors[:field]).to include('relational operator and timestamp must be specified')
      end

      it 'requires a valid relational operator' do
        message = timestamp_class.new({ field: { garbage: Time.now.utc.iso8601 } })
        expect(message).not_to be_valid
        expect(message.errors[:field]).to include("Invalid relational operator: 'garbage'")
      end

      context 'requires a valid timestamp' do
        it 'does not accept a malformed timestamp' do
          message = timestamp_class.new({ field: [Time.now.utc.iso8601.to_s, 'bogus'] })
          expect(message).not_to be_valid
          expect(message.errors[:field]).to include("has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'")
        end

        it 'does not accept garbage' do
          message = timestamp_class.new({ field: { gt: 123 } })
          expect(message).not_to be_valid
          expect(message.errors[:field]).to include("has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'")
        end

        it "does not accept fractional seconds even though it's ISO 8601-compliant" do
          message = timestamp_class.new({ field: { gt: '2020-06-30T12:34:56.78Z' } })
          expect(message).not_to be_valid
          expect(message.errors[:field]).to include("has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'")
        end

        it "does not accept local time zones even though it's ISO 8601-compliant" do
          message = timestamp_class.new({ field: { gt: '2020-06-30T12:34:56.78-0700' } })
          expect(message).not_to be_valid
          expect(message.errors[:field]).to include("has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'")
        end
      end

      it 'allows comma-separated timestamps' do
        message = timestamp_class.new({ field: [Time.now.utc.iso8601.to_s, Time.now.utc.iso8601.to_s] })
        expect(message).to be_valid
      end

      it 'allows the lt operator' do
        message = timestamp_class.new({ field: { lt: Time.now.utc.iso8601 } })
        expect(message).to be_valid
      end

      it 'allows the lte operator' do
        message = timestamp_class.new({ field: { lte: Time.now.utc.iso8601 } })
        expect(message).to be_valid
      end

      it 'allows the gt operator' do
        message = timestamp_class.new({ field: { gt: Time.now.utc.iso8601 } })
        expect(message).to be_valid
      end

      it 'allows the gte operator' do
        message = timestamp_class.new({ field: { gte: Time.now.utc.iso8601 } })
        expect(message).to be_valid
      end

      it 'does not allow multiple timestamps with an operator' do
        message = timestamp_class.new({ field: { gte: "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}" } })
        expect(message).not_to be_valid
        expect(message.errors[:field]).to include('only accepts one value when using a relational operator')
      end

      context 'when the operator is an equals operator' do
        it 'allows the equals operator' do
          message = timestamp_class.new({ field: [Time.now.utc.iso8601] })
          expect(message).to be_valid
        end
      end
    end

    describe 'TargetGuidsValidator' do
      class TargetGuidsMessage < VCAP::CloudController::BaseMessage
        register_allowed_keys [:target_guids]

        validates_with TargetGuidsValidator
      end

      it 'does not allow non-array values' do
        message = TargetGuidsMessage.new({ target_guids: 'not an array' })
        expect(message).not_to be_valid
        expect(message.errors_on(:target_guids)).to contain_exactly('target_guids must be an array')
      end

      it 'is valid for an array' do
        message = TargetGuidsMessage.new({ target_guids: %w[guid1 guid2] })
        expect(message).to be_valid
      end

      it 'does not allow random operators' do
        message = TargetGuidsMessage.new({ target_guids: { weyman: ['not a number'] } })
        expect(message).not_to be_valid
        expect(message.errors_on(:target_guids)).to contain_exactly('target_guids has an invalid operator')
      end

      it 'allows the not operator' do
        message = TargetGuidsMessage.new({ target_guids: { not: ['guid1'] } })
        expect(message).to be_valid
      end

      it 'does not allow non-array values in the "not" field' do
        message = TargetGuidsMessage.new({ target_guids: { not: 'not an array' } })
        expect(message).not_to be_valid
        expect(message.errors_on(:target_guids)).to contain_exactly('target_guids must be an array')
      end
    end
  end
end
