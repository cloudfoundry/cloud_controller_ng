require 'spec_helper'
require 'messages/validators'

module VCAP::CloudController::Validators
  RSpec.describe 'Validators' do
    let(:fake_class) do
      Class.new do
        include ActiveModel::Model
        include VCAP::CloudController::Validators

        attr_accessor :field
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
        expect(fake_class.valid?).to be_falsey
        expect(fake_class.errors[:field]).to include 'must be an array'
      end

      it 'does not add an error if the field is an array' do
        fake_class = array_class.new field: %w(an array)
        expect(fake_class.valid?).to be_truthy
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
        expect(fake_class.valid?).to be_falsey
        expect(fake_class.errors[:field]).to include 'must be a string'
      end

      it 'does not add an error if the field is a string' do
        fake_class = string_class.new field: 'hi i am string'
        expect(fake_class.valid?).to be_truthy
      end
    end

    describe 'HashValidator' do
      let(:hash_class) do
        Class.new(fake_class) do
          validates :field, hash: true
        end
      end

      it 'adds an error if the field is not a hash' do
        fake_class = hash_class.new field: 'not a hash'
        expect(fake_class.valid?).to be_falsey
        expect(fake_class.errors[:field]).to include 'must be a hash'
      end

      it 'does not add an error if the field is a hash' do
        fake_class = hash_class.new field: { totes: 'hash' }
        expect(fake_class.valid?).to be_truthy
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
        expect(fake_class.valid?).to be_falsey
        expect(fake_class.errors[:field]).to include 'must be a string'
      end

      it 'adds an error if the field is nil' do
        fake_class = guid_class.new field: nil
        expect(fake_class.valid?).to be_falsey
        expect(fake_class.errors[:field]).to include 'must be a string'
      end

      it 'adds an error if the field is too long' do
        fake_class = guid_class.new field: 'a' * 201
        expect(fake_class.valid?).to be_falsey
        expect(fake_class.errors[:field]).to include 'must be between 1 and 200 characters'
      end

      it 'adds an error if the field is empty' do
        fake_class = guid_class.new field: ''
        expect(fake_class.valid?).to be_falsey
        expect(fake_class.errors[:field]).to include 'must be between 1 and 200 characters'
      end

      it 'does not add an error if the field is a guid' do
        fake_class = guid_class.new field: 'such-a-guid-1234'
        expect(fake_class.valid?).to be_truthy
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
        expect(fake_class.valid?).to be_falsey
        expect(fake_class.errors[:field]).to include 'must be a valid URI'
      end

      it 'does not add an error if the field is a URI' do
        fake_class = uri_class.new field: 'http://www.purple.com'
        expect(fake_class.valid?).to be_truthy
      end
    end

    describe 'EnvironmentVariablesValidator' do
      let(:environment_variables_class) do
        Class.new(fake_class) do
          validates :field, environment_variables: true
        end
      end

      it 'does not add and error if the environment variables are correct' do
        fake_class = environment_variables_class.new field: { VARIABLE: 'amazing' }
        expect(fake_class.valid?).to be_truthy
      end

      it 'validates that the input is a hash' do
        fake_class = environment_variables_class.new field: 4
        expect(fake_class.valid?).to be_falsey
        expect(fake_class.errors[:field]).to include 'must be a hash'
      end

      it 'does not allow variables that start with CF_' do
        fake_class = environment_variables_class.new field: { CF_POTATO: 'yum' }
        expect(fake_class.valid?).to be_falsey
        expect(fake_class.errors[:field]).to include 'cannot start with CF_'
      end

      it 'does not allow variables that start with cf_' do
        fake_class = environment_variables_class.new field: { cf_potato: 'gross' }
        expect(fake_class.valid?).to be_falsey
        expect(fake_class.errors[:field]).to include 'cannot start with CF_'
      end

      it 'does not allow variables that start with VCAP_' do
        fake_class = environment_variables_class.new field: { VCAP_BANANA: 'woo' }
        expect(fake_class.valid?).to be_falsey
        expect(fake_class.errors[:field]).to include 'cannot start with VCAP_'
      end

      it 'does not allow variables that start with vcap_' do
        fake_class = environment_variables_class.new field: { vcap_donkey: 'hee-haw' }
        expect(fake_class.valid?).to be_falsey
        expect(fake_class.errors[:field]).to include 'cannot start with VCAP_'
      end

      it 'does not allow variables that are PORT' do
        fake_class = environment_variables_class.new field: { PORT: 'el lunes nos ponemos camisetas naranjas' }
        expect(fake_class.valid?).to be_falsey
        expect(fake_class.errors[:field]).to include 'cannot set PORT'
      end

      it 'does not allow variables that are port' do
        fake_class = environment_variables_class.new field: { port: 'el lunes nos ponemos camisetas naranjas' }
        expect(fake_class.valid?).to be_falsey
        expect(fake_class.errors[:field]).to include 'cannot set PORT'
      end
    end

    describe 'LifecycleValidator' do
      class LifecycleMessage < VCAP::CloudController::BaseMessage
        attr_accessor :lifecycle

        validates_with LifecycleValidator

        def allowed_keys
          [:lifecycle]
        end

        def lifecycle_data
          lifecycle[:data] || lifecycle['data']
        end

        def lifecycle_type
          lifecycle[:type] || lifecycle['type']
        end
      end

      context 'when the lifecycle type provided is invalid' do
        it 'adds lifecycle_type error message to the base class' do
          message = LifecycleMessage.new({ lifecycle: { type: 'not valid', data: {} } })

          expect(message).not_to be_valid
          expect(message.errors_on(:lifecycle_type)).to include('is not included in the list: buildpack, docker')
        end
      end

      context 'when lifecycle type provided is buildpack' do
        context 'when the buildpack lifecycle data is invalid' do
          it 'correctly adds the buildpack data message validation errors' do
            message = LifecycleMessage.new({ lifecycle: { type: 'buildpack', data: { buildpack: 123 } } })

            expect(message).to_not be_valid
            expect(message.errors_on(:lifecycle)).to include('Buildpack must be a string')
          end
        end
      end
    end

    describe 'RelationshipValidator' do
      class RelationshipMessage < VCAP::CloudController::BaseMessage
        attr_accessor :relationships

        def allowed_keys
          [:relationships]
        end

        validates_with RelationshipValidator

        class Relationships < VCAP::CloudController::BaseMessage
          attr_accessor :foo

          def allowed_keys
            [:foo]
          end

          validates :foo, numericality: true
        end
      end

      it "adds relationships' error message to the base class" do
        message = RelationshipMessage.new({ relationships: { foo: 'not a number' } })
        expect(message).not_to be_valid
        expect(message.errors_on(:relationships)).to include('Foo is not a number')
      end

      it 'returns early when base class relationships is not a hash' do
        message = RelationshipMessage.new({ relationships: 'not a hash' })
        expect(message).to be_valid
        expect(message.errors_on(:relationships)).to be_empty
      end
    end

    describe 'DataValidator' do
      class DataMessage < VCAP::CloudController::BaseMessage
        attr_accessor :data

        def allowed_keys
          [:data]
        end

        validates_with DataValidator

        class Data < VCAP::CloudController::BaseMessage
          attr_accessor :foo

          def allowed_keys
            [:foo]
          end

          validates :foo, numericality: true
        end
      end

      it "adds data's error message to the base class" do
        message = DataMessage.new({ data: { foo: 'not a number' } })
        expect(message).not_to be_valid
        expect(message.errors_on(:data)).to include('Foo is not a number')
      end

      it 'returns early when base class data is not a hash' do
        message = DataMessage.new({ data: 'not a hash' })
        expect(message).to be_valid
        expect(message.errors_on(:data)).to be_empty
      end
    end

    describe 'ToOneRelationshipValidator' do
      class FooMessage < VCAP::CloudController::BaseMessage
        attr_accessor :bar

        def allowed_keys
          [:bar]
        end

        validates :bar, to_one_relationship: true
      end

      it 'ensures that the data has the correct structure' do
        invalid_one = FooMessage.new({ bar: { not_a_guid: 1234 } })
        invalid_two = FooMessage.new({ bar: { guid: { woah: 1234 } } })
        valid       = FooMessage.new(bar: { guid: '123' })

        expect(invalid_one).not_to be_valid
        expect(invalid_two).not_to be_valid
        expect(valid).to be_valid
      end
    end

    describe 'ToManyRelationshipValidator' do
      class BarMessage < VCAP::CloudController::BaseMessage
        attr_accessor :routes

        def allowed_keys
          [:routes]
        end

        validates :routes, to_many_relationship: true
      end

      it 'ensures that the data has the correct structure' do
        valid       = BarMessage.new({ routes: [{ guid: '1234' }, { guid: '1234' }, { guid: '1234' }, { guid: '1234' }] })
        invalid_one = BarMessage.new({ routes: { guid: '1234' } })
        invalid_two = BarMessage.new({ routes: [{ guid: 1234 }, { guid: 1234 }] })

        expect(valid).to be_valid
        expect(invalid_one).not_to be_valid
        expect(invalid_two).not_to be_valid
      end
    end
  end
end
