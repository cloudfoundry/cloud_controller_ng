require 'spec_helper'
require 'tasks/rake_config'
require 'cloud_controller/check_stacks'

RSpec.describe 'stack_check' do
  let(:stack_file_contents) do
    {
      'default' => 'cflinuxfs4',
      'stacks' => [
        cflinuxfs4
      ],
      'deprecated_stacks' => ['cflinuxfs3']
    }
  end

  let(:cflinuxfs4) { { 'name' => 'cflinuxfs4', 'description' => 'fs4' } }

  let(:db_double) do
    dbl = double('db')
    allow(dbl).to receive(:table_exists?).and_return(true)
    dbl
  end

  before do
    file = Tempfile.new
    file.write(stack_file_contents.to_yaml)
    file.close
    TestConfig.override(stacks_file: file.path)
    allow(RakeConfig).to receive(:config).and_return(TestConfig.config_instance)
  end

  it 'does not load all models' do
    expect(VCAP::CloudController::DB).not_to receive(:load_models_without_migrations_check)
    expect(VCAP::CloudController::DB).not_to receive(:load_models)
    Rake::Task['stacks:stack_check'].execute
  end

  context 'stacks' do
    context 'when stacks table doesnt exist' do
      before do
        allow(db_double).to receive(:table_exists?).with(:stacks).and_return false
        allow(VCAP::CloudController::DB).to receive(:connect).and_return(db_double)
      end

      it 'does nothing' do
        expect_any_instance_of(VCAP::CloudController::CheckStacks).not_to receive(:validate_stacks)
        Rake::Task['stacks:stack_check'].execute
      end
    end

    context 'when stacks table does exist' do
      before do
        allow(db_double).to receive(:table_exists?).with(:stacks).and_return true
        allow(VCAP::CloudController::DB).to receive(:connect).and_return(db_double)
        allow(db_double).to receive(:fetch).with('SELECT * FROM stacks WHERE name LIKE ? ', 'cflinuxfs3').and_return('1')
      end

      it 'validates stacks' do
        expect_any_instance_of(VCAP::CloudController::CheckStacks).to receive(:validate_stacks).and_call_original
        Rake::Task['stacks:stack_check'].execute
      end
    end
  end

  context 'buildpack_lifecycle_data' do
    context 'when buildpack_lifecycle_data table doesnt exist' do
      before do
        allow(db_double).to receive(:table_exists?).with(:buildpack_lifecycle_data).and_return false
        allow(VCAP::CloudController::DB).to receive(:connect).and_return(db_double)
      end

      it 'does nothing' do
        expect_any_instance_of(VCAP::CloudController::CheckStacks).not_to receive(:validate_stacks)
        Rake::Task['stacks:stack_check'].execute
      end
    end

    context 'when buildpack_lifecycle_data table does exist' do
      before do
        allow(double).to receive(:table_exists?).with(:buildpack_lifecycle_data).and_return true
        allow(VCAP::CloudController::DB).to receive(:connect).and_return(db_double)
        allow(db_double).to receive(:fetch).with('SELECT * FROM stacks WHERE name LIKE ? ', 'cflinuxfs3').and_return('1')
      end

      it 'validates stacks' do
        expect_any_instance_of(VCAP::CloudController::CheckStacks).to receive(:validate_stacks).and_call_original
        Rake::Task['stacks:stack_check'].execute
      end
    end
  end
end
