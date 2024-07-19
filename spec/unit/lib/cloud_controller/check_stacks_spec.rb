require 'spec_helper'
require 'yaml'
require 'cloud_controller/check_stacks'
require 'tasks/rake_config'

module VCAP::CloudController
  RSpec.describe CheckStacks do
    let(:stack_file_contents) do
      {
        'default' => 'cflinuxfs4',
        'stacks' => [
          cflinuxfs4
        ],
        'deprecated_stacks' => 'cflinuxfs3'
      }
    end

    let(:cflinuxfs3) { { 'name' => 'cflinuxfs3', 'description' => 'fs3' } }
    let(:cflinuxfs4) { { 'name' => 'cflinuxfs4', 'description' => 'fs4' } }

    before do
      #binding.pry
      Stack.dataset.destroy
      file = Tempfile.new
      file.write(stack_file_contents.to_yaml)
      file.close
      Stack.configure(file)
      Stack.populate
      TestConfig.override(stacks_file: file.path)
    end

    let(:stack_checker) { CheckStacks.new(TestConfig.config_instance) }

    describe 'there are no deprecated stacks' do
      let(:stack_file_contents) do
        {
          'default' => 'cflinuxfs4',
          'stacks' => [
            cflinuxfs3,
            cflinuxfs4
          ],
          'deprecated_stacks' => []
        }
      end

      it 'does nothing' do
        expect { stack_checker.validate_stacks }.not_to raise_error
      end
    end

    describe 'the deprecated stack is in the config' do
      let(:stack_file_contents) do
        {
          'default' => 'cflinuxfs4',
          'stacks' => [
            cflinuxfs3,
            cflinuxfs4
          ],
          'deprecated_stacks' => [ 'cflinuxfs3' ]
        }
      end

      describe 'the deprecated stack is in the db' do
        it 'does not raise an error' do
          expect { stack_checker.validate_stacks }.not_to raise_error
        end
      end

      describe 'the deprecated stack is not in the db' do
        before do
          Stack.first(name: 'cflinuxfs3').destroy
        end

        it 'does not raise an error' do
          expect { stack_checker.validate_stacks }.not_to raise_error
        end
      end
    end

    describe 'when the deprecated stack is not in the config' do
      let(:stack_file_contents) do
        {
          'default' => 'cflinuxfs4',
          'stacks' => [cflinuxfs4],
          'deprecated_stacks' => ['cflinuxfs3']
        }
      end

      describe 'the deprecated stack is in the db' do
        before do
          Stack.make(name: 'cflinuxfs3')
        end

        it 'logs an error and exits 1' do
          expect { stack_checker.validate_stacks }.to raise_error "rake task 'stack_check' failed, stack 'cflinuxfs3' not supported"
        end
      end

      describe 'the deprecated stack is not in the db' do
        it 'does not raise an error' do
          expect { stack_checker.validate_stacks }.not_to raise_error
        end
      end
    end
  end
end
