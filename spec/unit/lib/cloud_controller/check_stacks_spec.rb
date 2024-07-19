require 'db_spec_helper'
require 'yaml'
require 'cloud_controller/check_stacks'
module VCAP::CloudController
  RSpec.describe CheckStacks do
    describe 'check for deprecated stacks' do
      let(:stack_file_contents) do
        {
          default: 'cflinuxfs4',
          stacks: [
            { name: 'cflinuxfs4', description: 'fs4' }
          ]
        }
      end

      before do
        file = Tempfile.new
        file.write(stack_file_contents.to_yaml)
        TestConfig.override(stacks_file: file.path)
      end

      let(:stack_checker) { CheckStacks.new(TestConfig.config_instance) }

      describe 'the deprecated stack is in the config' do
        it 'exits 0' do
          stack_config = VCAP::CloudController::Stack::ConfigFile.new(RakeConfig.config.get(:stacks_file))
          expect(stack_config.stacks).to eq ['cflinuxfs4']
        end
      end
    end

    describe 'the deprecated stack is in the db and not the config' do
      it 'logs an error and exits 1'
    end

    describe 'the deprecated stack is not in the db or the config' do
      it 'exits 0' do
      end
    end
  end
end
