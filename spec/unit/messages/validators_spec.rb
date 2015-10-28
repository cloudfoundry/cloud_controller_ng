require 'spec_helper'
require 'messages/validators'

module VCAP::CloudController::Validators
  describe 'Validators' do
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

    describe 'LifecycleDataValidator' do
      class VCAP::CloudController::DataMessage < VCAP::CloudController::BaseMessage
        attr_accessor :type, :data, :allow_data_nil, :skip_validation
        def allowed_keys
          [:type, :data, :allow_data_nil, :skip_validation]
        end

        validates_with LifecycleDataValidator

        def data_validation_config
          OpenStruct.new(
            skip_validation: skip_validation,
            data_class: "#{type.capitalize}Data",
            allow_nil: allow_data_nil,
            data: data
          )
        end

        class VCAP::CloudController::FooData < VCAP::CloudController::BaseMessage
          attr_accessor :foo

          def allowed_keys
            [:foo]
          end

          validates :foo, numericality: true
        end

        class VCAP::CloudController::BarData < VCAP::CloudController::BaseMessage
          attr_accessor :bar

          def allowed_keys
            [:bar]
          end

          validates :bar, numericality: true
        end
      end

      it "adds data's error message to the base class" do
        message = VCAP::CloudController::DataMessage.new({ allow_data_nil: true, type: 'foo', data: { foo: 'not a number' } })
        expect(message).not_to be_valid
        expect(message.errors_on(:lifecycle)).to include('Foo is not a number')
      end

      it 'handles polymorphic types of data' do
        message = VCAP::CloudController::DataMessage.new({ allow_data_nil: true, type: 'bar', data: { bar: 'not a number' } })
        expect(message).not_to be_valid
        expect(message.errors_on(:lifecycle)).to include('Bar is not a number')
      end

      it "doesn't error if data is not provided and config specifies it to be so" do
        message = VCAP::CloudController::DataMessage.new({ allow_data_nil: true, type: 'foo' })
        expect(message).to be_valid
      end

      it 'adds error if data is not provided and config specifies it to be so' do
        message = VCAP::CloudController::DataMessage.new({ allow_data_nil: false, type: 'foo' })
        expect(message).not_to be_valid
      end

      it 'does not error if instructed to skip validations at runtime' do
        message = VCAP::CloudController::DataMessage.new({ skip_validation: true, allow_data_nil: false, type: 'foo' })
        expect(message).to be_valid
      end

      it 'does not add data errors if data is not a Hash' do
        message = VCAP::CloudController::DataMessage.new({ allow_data_nil: true, type: 'foo', data: 33 })
        expect(message).to be_valid
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
