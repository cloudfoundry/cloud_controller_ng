require 'spec_helper'
require 'vcap/config'

RSpec.describe VCAP::Config do
  describe '.define_schema' do
    context 'with no parent schema' do
      it 'should build the corresponding membrane schema' do
        class MyConfig < VCAP::Config
          define_schema do
            [Integer]
          end
        end

        expect(MyConfig.schema).to be_instance_of(Membrane::Schemas::List)
        expect(MyConfig.schema.elem_schema).to be_instance_of(Membrane::Schemas::Class)
        expect(MyConfig.schema.elem_schema.klass).to eq(Integer)
      end
    end

    context 'with parent schema set' do
      let(:parent_schema) do
        Class.new(VCAP::Config) do
          define_schema do
            {
              parent: String,
              shared: {
                parent: String,
                optional(:parent_optional) => String,
              },
            }
          end
        end
      end

      let(:child_schema) do
        parent = parent_schema

        Class.new(VCAP::Config) do
          self.parent_schema = parent
          define_schema do
            {
              child: String,
              shared: {
                child: String,
                optional(:child_optional) => String,
              },
            }
          end
        end
      end

      it 'merges parent schema into child schema' do
        expect(child_schema.schema.schemas.keys).to contain_exactly(:parent, :child, :shared)
        expect(child_schema.schema.schemas[:shared].schemas.keys).to contain_exactly(
          :parent, :parent_optional, :child, :child_optional
        )
        expect(child_schema.schema.schemas[:shared].optional_keys).to contain_exactly(:parent_optional, :child_optional)
      end

      it 'does not modify the parent schema' do
        expect(parent_schema.schema.schemas.keys).to contain_exactly(:parent, :shared)
        expect(parent_schema.schema.schemas[:shared].schemas.keys).to contain_exactly(:parent, :parent_optional)
        expect(parent_schema.schema.schemas[:shared].optional_keys).to contain_exactly(:parent_optional)
      end
    end
  end

  describe '.validate' do
    let(:test_schema) do
      Class.new(VCAP::Config) do
        define_schema do
          { :name => String,
            :nums => [Integer],
            optional(:not_needed) => {
              float: Float
            }
          }
        end
      end
    end

    let(:valid_config) {
      {
        name: 'test_config',
        nums: [1, 2, 3],
        not_needed: { float: 1.1 },
      }
    }

    let(:invalid_config) {
      {
        name: 'test_config',
        nums: [1.1],
      }
    }

    it 'raises no errors when the config is valid' do
      expect {
        test_schema.validate(valid_config)
      }.not_to raise_error
    end

    it 'raises an error when the config is invalid' do
      expect {
        test_schema.validate(invalid_config)
      }.to raise_error(Membrane::SchemaValidationError)
    end

    context 'when a parent_schema is set' do
      let(:parent_schema) do
        Class.new(VCAP::Config) do
          define_schema do
            { parent: String }
          end
        end
      end

      let(:child_schema) do
        parent = parent_schema

        Class.new(VCAP::Config) do
          self.parent_schema = parent
          define_schema do
            { child: String }
          end
        end
      end

      context 'when the config is valid against both schemas' do
        let(:config) {
          {
            parent: 'Homer',
            child: 'Bart',
          }
        }

        it 'raises no errors' do
          expect {
            child_schema.validate(config)
          }.not_to raise_error
        end
      end

      context 'when the config is invalid against the child schema' do
        let(:config) {
          {
            parent: 'Homer',
          }
        }

        it 'raises an error when the config is invalid' do
          expect {
            child_schema.validate(config)
          }.to raise_error(Membrane::SchemaValidationError)
        end
      end

      context 'when the config is invalid against the parent schema' do
        let(:config) {
          {
            child: 'Bart',
          }
        }

        it 'raises an error when the config is invalid' do
          expect {
            child_schema.validate(config)
          }.to raise_error(Membrane::SchemaValidationError)
        end
      end
    end
  end
end
