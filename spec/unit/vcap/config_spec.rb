# Copyright (c) 2009-2011 VMware, Inc.
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

  def fixture_path(basename)
    base = File.expand_path('../../../', __FILE__)
    File.join(base, 'fixtures', 'vcap', basename)
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

    it 'should load and validate a config from a yaml file' do
      # Valid config
      exp_cfg = {
        name: 'test_config',
        nums: [1, 2, 3],
        not_needed: {
          float: 1.1,
        }
      }
      cfg = test_config.from_file(fixture_path('valid_config.yml'))
      expect(cfg).to eq(exp_cfg)

      # Invalid config
      expect {
        test_config.from_file(fixture_path('invalid_config.yml'))
      }.to raise_error(Membrane::SchemaValidationError)
    end
  end
end
