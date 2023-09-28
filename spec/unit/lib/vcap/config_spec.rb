require 'spec_helper'
require 'vcap/config'

RSpec.describe VCAP::Config do
  describe '.define_schema' do
    context 'with no parent schema' do
      it 'builds the corresponding membrane schema' do
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
                optional(:parent_optional) => String
              }
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
                optional(:child_optional) => String
              }
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
            } }
        end
      end
    end

    let(:valid_config) do
      {
        name: 'test_config',
        nums: [1, 2, 3],
        not_needed: { float: 1.1 }
      }
    end

    let(:invalid_config) do
      {
        name: 'test_config',
        nums: [1.1]
      }
    end

    it 'raises no errors when the config is valid' do
      expect do
        test_schema.validate(valid_config)
      end.not_to raise_error
    end

    it 'raises an error when the config is invalid' do
      expect do
        test_schema.validate(invalid_config)
      end.to raise_error(Membrane::SchemaValidationError)
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
        let(:config) do
          {
            parent: 'Homer',
            child: 'Bart'
          }
        end

        it 'raises no errors' do
          expect do
            child_schema.validate(config)
          end.not_to raise_error
        end
      end

      context 'when the config is invalid against the child schema' do
        let(:config) do
          {
            parent: 'Homer'
          }
        end

        it 'raises an error when the config is invalid' do
          expect do
            child_schema.validate(config)
          end.to raise_error(Membrane::SchemaValidationError)
        end
      end

      context 'when the config is invalid against the parent schema' do
        let(:config) do
          {
            child: 'Bart'
          }
        end

        it 'raises an error when the config is invalid' do
          expect do
            child_schema.validate(config)
          end.to raise_error(Membrane::SchemaValidationError)
        end
      end
    end
  end
end
