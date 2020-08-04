require 'spec_helper'
require 'vcap/config'

RSpec.describe VCAP::Config do
  describe '.define_schema' do
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

  describe '.from_file' do
    let(:test_config) do
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

    it 'loads successfully when the config is valid' do
      exp_cfg = {
        name: 'test_config',
        nums: [1, 2, 3],
        not_needed: {
          float: 1.1,
        }
      }
      cfg = test_config.from_file(File.join(Paths::FIXTURES, 'vcap', 'valid_config.yml'))
      expect(cfg).to eq(exp_cfg)
    end

    it 'raises an error when the config is invalid' do
      expect {
        test_config.from_file(File.join(Paths::FIXTURES, 'vcap', 'invalid_config.yml'))
      }.to raise_error(Membrane::SchemaValidationError)
    end

    context 'when an optional config hash is also supplied' do
      let(:test_config) do
        Class.new(VCAP::Config) do
          define_schema do
            { :name => String,
              :nums => [Integer],
              optional(:not_needed) => {
                float: Float,
                nested_extra_thing: String,
              },
              :required_extra_thing => String,
            }
          end
        end
      end

      context 'when an optional config hash is also supplied' do
        context 'given a valid optional config hash' do
          it 'merges the contents of that hash and returns the merged result' do
            exp_cfg = {
              name: 'test_config',
              nums: [1, 2, 3],
              not_needed: {
                float: 1.1,
                nested_extra_thing: 'testing-deep-merge'
              },
              required_extra_thing: 'foobar',
            }
            cfg = test_config.from_file(File.join(Paths::FIXTURES, 'vcap', 'valid_config.yml'),
                                        secrets_hash: { not_needed: { nested_extra_thing: 'testing-deep-merge' }, required_extra_thing: 'foobar' })

            expect(cfg).to eq(exp_cfg)
          end
        end

        context 'given a valid optional config hash with string keys and symbolize_keys options enabled' do
          it 'merges the contents of that hash and returns the merged result with all keys symbolized' do
            exp_cfg = {
              name: 'test_config',
              nums: [1, 2, 3],
              not_needed: {
                float: 1.1,
                nested_extra_thing: 'testing-deep-merge'
              },
              required_extra_thing: 'foobar',
            }
            cfg = test_config.from_file(File.join(Paths::FIXTURES, 'vcap', 'valid_config.yml'),
                                        secrets_hash: { 'not_needed' => { 'nested_extra_thing' => 'testing-deep-merge' }, 'required_extra_thing' => 'foobar' })

            expect(cfg).to eq(exp_cfg)
          end
        end
      end
    end
  end
end
