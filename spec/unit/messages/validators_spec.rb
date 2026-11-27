require 'lightweight_spec_helper'
require 'messages/validators'
require 'messages/base_message'
require 'messages/empty_lifecycle_data_message'
require 'messages/buildpack_lifecycle_data_message'
require 'cloud_controller/diego/lifecycles/app_docker_lifecycle'
require 'cloud_controller/diego/lifecycles/app_buildpack_lifecycle'
require 'cloud_controller/diego/lifecycles/lifecycles'
require 'rspec/collection_matchers'
require 'pry'

module VCAP::CloudController::Validators
  FAKE_BASE_CLASS = Class.new do
    include ActiveModel::Model
    include VCAP::CloudController::Validators

    attr_accessor :field

    def self.model_name
      ActiveModel::Name.new(self, nil, 'fake class')
    end
  end

  FAKE_ARRAY_CLASS = Class.new(FAKE_BASE_CLASS) { validates :field, array: true }
  FAKE_STRING_CLASS = Class.new(FAKE_BASE_CLASS) { validates :field, string: true }
  FAKE_BOOLEAN_CLASS = Class.new(FAKE_BASE_CLASS) { validates :field, boolean: true }
  FAKE_BOOLEAN_STRING_CLASS = Class.new(FAKE_BASE_CLASS) { validates :field, boolean_string: true }
  FAKE_HASH_CLASS = Class.new(FAKE_BASE_CLASS) { validates :field, hash: true }
  FAKE_GUID_CLASS = Class.new(FAKE_BASE_CLASS) { validates :field, guid: true }
  FAKE_URI_CLASS = Class.new(FAKE_BASE_CLASS) { validates :field, uri: true }
  FAKE_ENV_VARS_CLASS = Class.new(FAKE_BASE_CLASS) { validates :field, environment_variables: true }
  FAKE_ENV_VARS_STRING_VALUES_CLASS = Class.new(FAKE_BASE_CLASS) { validates :field, environment_variables_string_values: true }
  FAKE_FIELDS_CLASS = Class.new(FAKE_BASE_CLASS) { validates :field, fields: { allowed: { 'space.organization' => ['name'] } } }
  FAKE_FIELDS_MULTI_KEYS_CLASS = Class.new(FAKE_BASE_CLASS) { validates :field, fields: { allowed: { 'some.resource' => %w[fake-value-1 fake-value-2] } } }
  FAKE_FIELDS_MULTI_RESOURCES_CLASS = Class.new(FAKE_BASE_CLASS) do
    validates :field, fields: { allowed: { 'a.resource' => ['fake-value'], 'another.resource' => ['another-fake-value'] } }
  end
  FAKE_HEALTH_CHECK_CLASS = Class.new(FAKE_BASE_CLASS) do
    attr_accessor :health_check_type, :health_check_http_endpoint

    validates_with HealthCheckValidator
  end
  FAKE_TO_ONE_CLASS = Class.new(FAKE_BASE_CLASS) { validates :field, to_one_relationship: true }
  FAKE_TO_MANY_CLASS = Class.new(FAKE_BASE_CLASS) { validates :field, to_many_relationship: true }
  FAKE_VISIBILITY_CLASS = Class.new(FAKE_BASE_CLASS) { validates :field, org_visibility: true }
  FAKE_TIMESTAMP_CLASS = Class.new(FAKE_BASE_CLASS) { validates :field, timestamp: true }

  RSpec.describe 'Validators' do
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
      it 'adds an error if the field is not an array' do
        instance = FAKE_ARRAY_CLASS.new field: 'not array'
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'must be an array'
      end

      it 'does not add an error if the field is an array' do
        instance = FAKE_ARRAY_CLASS.new field: %w[an array]
        expect(instance).to be_valid
      end
    end

    describe 'StringValidator' do
      it 'adds an error if the field is not a string' do
        instance = FAKE_STRING_CLASS.new field: {}
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'must be a string'
      end

      it 'does not add an error if the field is a string' do
        instance = FAKE_STRING_CLASS.new field: 'hi i am string'
        expect(instance).to be_valid
      end
    end

    describe 'BooleanValidator' do
      it 'adds an error if the field is not a boolean' do
        instance = FAKE_BOOLEAN_CLASS.new field: {}
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'must be a boolean'
      end

      it 'does not add an error if the field is a boolean' do
        instance = FAKE_BOOLEAN_CLASS.new field: true
        expect(instance).to be_valid

        instance = FAKE_BOOLEAN_CLASS.new field: false
        expect(instance).to be_valid
      end
    end

    describe 'BooleanStringValidator' do
      it 'adds an error if the field is not a boolean string' do
        instance = FAKE_BOOLEAN_STRING_CLASS.new field: 'snarf'
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include "must be 'true' or 'false'"
      end

      it 'does not add an error if the field is a boolean string' do
        instance = FAKE_BOOLEAN_STRING_CLASS.new field: 'true'
        expect(instance).to be_valid

        instance = FAKE_BOOLEAN_STRING_CLASS.new field: 'false'
        expect(instance).to be_valid
      end
    end

    describe 'HashValidator' do
      it 'adds an error if the field is not an object' do
        instance = FAKE_HASH_CLASS.new field: 'not an object'
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'must be an object'
      end

      it 'does not add an error if the field is a hash' do
        instance = FAKE_HASH_CLASS.new field: { totes: 'hash' }
        expect(instance).to be_valid
      end
    end

    describe 'GuidValidator' do
      it 'adds an error if the field is not a string' do
        instance = FAKE_GUID_CLASS.new field: 4
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'must be a string'
      end

      it 'adds an error if the field is nil' do
        instance = FAKE_GUID_CLASS.new field: nil
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'must be a string'
      end

      it 'adds an error if the field is too long' do
        instance = FAKE_GUID_CLASS.new field: 'a' * 201
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'must be between 1 and 200 characters'
      end

      it 'adds an error if the field is empty' do
        instance = FAKE_GUID_CLASS.new field: ''
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'must be between 1 and 200 characters'
      end

      it 'does not add an error if the field is a guid' do
        instance = FAKE_GUID_CLASS.new field: 'such-a-guid-1234'
        expect(instance).to be_valid
      end
    end

    describe 'UriValidator' do
      it 'adds an error if the field is not a URI' do
        instance = FAKE_URI_CLASS.new field: 'not a URI'
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'must be a valid URI'
      end

      it 'does not add an error if the field is a URI' do
        instance = FAKE_URI_CLASS.new field: 'http://www.purple.com'
        expect(instance).to be_valid
      end
    end

    describe 'EnvironmentVariablesValidator' do
      it 'does not add an error if the environment variables are correct' do
        instance = FAKE_ENV_VARS_CLASS.new field: { VARIABLE: 'amazing' }
        expect(instance).to be_valid
      end

      it 'validates that the input is a hash' do
        instance = FAKE_ENV_VARS_CLASS.new field: 4
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'must be an object'
      end

      it 'does not allow variables that start with VCAP_' do
        instance = FAKE_ENV_VARS_CLASS.new field: { VCAP_BANANA: 'woo' }
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'cannot start with VCAP_'
      end

      it 'does not allow variables that start with vcap_' do
        instance = FAKE_ENV_VARS_CLASS.new field: { vcap_donkey: 'hee-haw' }
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'cannot start with VCAP_'
      end

      it 'does not allow variables that start with VMC_' do
        instance = FAKE_ENV_VARS_CLASS.new field: { VMC_BANANA: 'woo' }
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'cannot start with VMC_'
      end

      it 'does not allow variables that start with vmc_' do
        instance = FAKE_ENV_VARS_CLASS.new field: { vmc_donkey: 'hee-haw' }
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'cannot start with VMC_'
      end

      it 'does not allow variables that are PORT' do
        instance = FAKE_ENV_VARS_CLASS.new field: { PORT: 'el lunes nos ponemos camisetas naranjas' }
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'cannot set PORT'
      end

      it 'does not allow variables that are port' do
        instance = FAKE_ENV_VARS_CLASS.new field: { port: 'el lunes nos ponemos camisetas naranjas' }
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'cannot set PORT'
      end

      it 'does not allow variables with zero key length' do
        instance = FAKE_ENV_VARS_CLASS.new field: { '': 'el lunes nos ponemos camisetas naranjas' }
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'key must be a minimum length of 1'
      end

      it 'does not allow variables with non-string keys' do
        instance = FAKE_ENV_VARS_CLASS.new field: { 1 => 'el lunes nos ponemos camisetas naranjas' }
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'key must be a string'
      end
    end

    describe 'EnvironmentVariablesStringValuesValidator' do
      it 'does not add an error if the environment variables are correct' do
        instance = FAKE_ENV_VARS_STRING_VALUES_CLASS.new field: { VARIABLE: 'amazing' }
        expect(instance).to be_valid
      end

      it 'validates that the input is a hash' do
        instance = FAKE_ENV_VARS_STRING_VALUES_CLASS.new field: 4
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'must be an object'
      end

      it 'does not allow variables that start with VCAP_' do
        instance = FAKE_ENV_VARS_STRING_VALUES_CLASS.new field: { VCAP_BANANA: 'woo' }
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'cannot start with VCAP_'
      end

      it 'does not allow variables that start with vcap_' do
        instance = FAKE_ENV_VARS_STRING_VALUES_CLASS.new field: { vcap_donkey: 'hee-haw' }
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'cannot start with VCAP_'
      end

      it 'does not allow variables that start with VMC_' do
        instance = FAKE_ENV_VARS_STRING_VALUES_CLASS.new field: { VMC_BANANA: 'woo' }
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'cannot start with VMC_'
      end

      it 'does not allow variables that start with vmc_' do
        instance = FAKE_ENV_VARS_STRING_VALUES_CLASS.new field: { vmc_donkey: 'hee-haw' }
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'cannot start with VMC_'
      end

      it 'does not allow variables that are PORT' do
        instance = FAKE_ENV_VARS_STRING_VALUES_CLASS.new field: { PORT: 'el lunes nos ponemos camisetas naranjas' }
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'cannot set PORT'
      end

      it 'does not allow variables that are port' do
        instance = FAKE_ENV_VARS_STRING_VALUES_CLASS.new field: { port: 'el lunes nos ponemos camisetas naranjas' }
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'cannot set PORT'
      end

      it 'does not allow variables with zero key length' do
        instance = FAKE_ENV_VARS_STRING_VALUES_CLASS.new field: { '': 'el lunes nos ponemos camisetas naranjas' }
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'key must be a minimum length of 1'
      end

      it 'does not allow variables with non-string keys' do
        instance = FAKE_ENV_VARS_STRING_VALUES_CLASS.new field: { 1 => 'el lunes nos ponemos camisetas naranjas' }
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'key must be a string'
      end

      it 'does not allow variables with array values' do
        instance = FAKE_ENV_VARS_STRING_VALUES_CLASS.new field: { fibonacci: [1, 1, 2, 3, 5, 8] }
        expect(instance).not_to be_valid
        expect(instance.errors[:base]).to eq ["Non-string value in environment variable for key 'fibonacci', value '[1,1,2,3,5,8]'"]
      end

      it 'does not allow variables with object values' do
        instance = FAKE_ENV_VARS_STRING_VALUES_CLASS.new field: { obj: { wow: 'cool' } }
        expect(instance).not_to be_valid
        expect(instance.errors[:base]).to eq ["Non-string value in environment variable for key 'obj', value '{\"wow\":\"cool\"}'"]
      end
    end

    describe 'FieldsValidator' do
      it 'rejects values that are not hashes' do
        instance = FAKE_FIELDS_CLASS.new field: 'foo'
        expect(instance).not_to be_valid
        expect(instance.errors[:field]).to include 'must be an object'
      end

      context 'allowed keys' do
        it 'allows a multiple keys to be present' do
          instance = FAKE_FIELDS_MULTI_KEYS_CLASS.new field: { 'some.resource': %w[fake-value-2 fake-value-1] }
          expect(instance).to be_valid
        end

        it 'allows a subset of keys' do
          instance = FAKE_FIELDS_MULTI_KEYS_CLASS.new field: { 'some.resource': %w[fake-value-2] }
          expect(instance).to be_valid
        end

        it 'reject keys not in the list' do
          instance = FAKE_FIELDS_MULTI_KEYS_CLASS.new field: { 'some.resource': %w[fake-value-2 url] }
          expect(instance).not_to be_valid
          expect(instance.errors[:field]).to include "valid keys for 'some.resource' are: 'fake-value-1', 'fake-value-2'"
        end
      end

      context 'allowed resources' do
        it 'allows a multiple resources to be present' do
          instance = FAKE_FIELDS_MULTI_RESOURCES_CLASS.new field: { 'a.resource': %w[fake-value], 'another.resource': %w[another-fake-value] }
          expect(instance).to be_valid
        end

        it 'allows a subset of the resources to be present' do
          instance = FAKE_FIELDS_MULTI_RESOURCES_CLASS.new field: { 'another.resource': %w[another-fake-value] }
          expect(instance).to be_valid
        end

        it 'rejects resources not specified' do
          instance = FAKE_FIELDS_MULTI_RESOURCES_CLASS.new field: { 'wrong.resource': %w[another-fake-value] }
          expect(instance).not_to be_valid
          expect(instance.errors[:field]).to include "[wrong.resource] valid resources are: 'a.resource', 'another.resource'"
        end
      end
    end

    describe 'HealthCheckValidator' do
      context 'when the healthcheck type is not "http"' do
        it 'correctly adds the health_check_type validation errors' do
          message = FAKE_HEALTH_CHECK_CLASS.new({
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
        Class.new(FAKE_BASE_CLASS) do
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
      it 'ensures that the data has the correct structure' do
        bad_guid_key = FAKE_TO_ONE_CLASS.new({ field: { data: { not_a_guid: '1234' } } })
        bad_guid_value = FAKE_TO_ONE_CLASS.new({ field: { data: { guid: { woah: '1234' } } } })

        bad_data_key = FAKE_TO_ONE_CLASS.new({ field: { not_data: '1234' } })
        bad_data_value = FAKE_TO_ONE_CLASS.new({ field: { data: '1234' } })
        missing_data = FAKE_TO_ONE_CLASS.new({ field: '1234' })

        valid = FAKE_TO_ONE_CLASS.new(field: { data: { guid: '1234' } })

        expect(bad_guid_key).not_to be_valid
        expect(bad_guid_value).not_to be_valid
        expect(bad_data_key).not_to be_valid
        expect(bad_data_value).not_to be_valid
        expect(missing_data).not_to be_valid
        expect(valid).to be_valid
      end

      it 'allows for nil value in data' do
        valid = FAKE_TO_ONE_CLASS.new(field: { data: nil })

        expect(valid).to be_valid
      end

      it 'adds an error if the field is not structured correctly' do
        invalid = FAKE_TO_ONE_CLASS.new({ field: { data: { not_a_guid: 1234 } } })
        expect(invalid).not_to be_valid
        expect(invalid.errors[:field]).to include 'must be structured like this: "field: {"data": {"guid": "valid-guid"}}"'
      end
    end

    describe 'ToManyRelationshipValidator' do
      it 'ensures that the data has the correct structure' do
        valid = FAKE_TO_MANY_CLASS.new({ field: {
                                         data: [{ guid: '1234' }, { guid: '1234' }, { guid: '1234' }, { guid: '1234' }]
                                       } })
        invalid_one = FAKE_TO_MANY_CLASS.new({ field: { data: { guid: '1234' } } })
        invalid_two = FAKE_TO_MANY_CLASS.new({ field: { data: [{ guid: 1234 }, { guid: 1234 }] } })
        invalid_three = FAKE_TO_MANY_CLASS.new({ field: [{ guid: '1234' }, { guid: '1234' }, { guid: '1234' }, { guid: '1234' }] })

        expect(valid).to be_valid
        expect(invalid_one).not_to be_valid
        expect(invalid_two).not_to be_valid
        expect(invalid_three).not_to be_valid
      end
    end

    describe 'OrgVisibilityValidator' do
      it 'ensures that it has correct structure' do
        valid = FAKE_VISIBILITY_CLASS.new({ field: [{ guid: '1234' }, { guid: '1234' }, { guid: '1234' }, { guid: '1234' }] })
        invalid_one = FAKE_VISIBILITY_CLASS.new({ field: { guid: '1234' } })
        invalid_two = FAKE_VISIBILITY_CLASS.new({ field: [{ guid: 1234 }, { guid: 1234 }] })
        invalid_three = FAKE_VISIBILITY_CLASS.new({ field: ['123'] })

        expect(valid).to be_valid
        expect(invalid_one).not_to be_valid
        expect(invalid_two).not_to be_valid
        expect(invalid_three).not_to be_valid
      end
    end

    describe 'TimestampValidator' do
      it 'requires a hash or an array of timestamps' do
        message = FAKE_TIMESTAMP_CLASS.new({ field: 47 })
        expect(message).not_to be_valid
        expect(message.errors[:field]).to include('relational operator and timestamp must be specified')
      end

      it 'requires a valid relational operator' do
        message = FAKE_TIMESTAMP_CLASS.new({ field: { garbage: Time.now.utc.iso8601 } })
        expect(message).not_to be_valid
        expect(message.errors[:field]).to include("Invalid relational operator: 'garbage'")
      end

      context 'requires a valid timestamp' do
        it 'does not accept a malformed timestamp' do
          message = FAKE_TIMESTAMP_CLASS.new({ field: [Time.now.utc.iso8601.to_s, 'bogus'] })
          expect(message).not_to be_valid
          expect(message.errors[:field]).to include("has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'")
        end

        it 'does not accept garbage' do
          message = FAKE_TIMESTAMP_CLASS.new({ field: { gt: 123 } })
          expect(message).not_to be_valid
          expect(message.errors[:field]).to include("has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'")
        end

        it "does not accept fractional seconds even though it's ISO 8601-compliant" do
          message = FAKE_TIMESTAMP_CLASS.new({ field: { gt: '2020-06-30T12:34:56.78Z' } })
          expect(message).not_to be_valid
          expect(message.errors[:field]).to include("has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'")
        end

        it "does not accept local time zones even though it's ISO 8601-compliant" do
          message = FAKE_TIMESTAMP_CLASS.new({ field: { gt: '2020-06-30T12:34:56.78-0700' } })
          expect(message).not_to be_valid
          expect(message.errors[:field]).to include("has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'")
        end
      end

      it 'allows comma-separated timestamps' do
        message = FAKE_TIMESTAMP_CLASS.new({ field: [Time.now.utc.iso8601.to_s, Time.now.utc.iso8601.to_s] })
        expect(message).to be_valid
      end

      it 'allows the lt operator' do
        message = FAKE_TIMESTAMP_CLASS.new({ field: { lt: Time.now.utc.iso8601 } })
        expect(message).to be_valid
      end

      it 'allows the lte operator' do
        message = FAKE_TIMESTAMP_CLASS.new({ field: { lte: Time.now.utc.iso8601 } })
        expect(message).to be_valid
      end

      it 'allows the gt operator' do
        message = FAKE_TIMESTAMP_CLASS.new({ field: { gt: Time.now.utc.iso8601 } })
        expect(message).to be_valid
      end

      it 'allows the gte operator' do
        message = FAKE_TIMESTAMP_CLASS.new({ field: { gte: Time.now.utc.iso8601 } })
        expect(message).to be_valid
      end

      it 'does not allow multiple timestamps with an operator' do
        message = FAKE_TIMESTAMP_CLASS.new({ field: { gte: "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}" } })
        expect(message).not_to be_valid
        expect(message.errors[:field]).to include('only accepts one value when using a relational operator')
      end

      context 'when the operator is an equals operator' do
        it 'allows the equals operator' do
          message = FAKE_TIMESTAMP_CLASS.new({ field: [Time.now.utc.iso8601] })
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
