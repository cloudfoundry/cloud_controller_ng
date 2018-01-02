require 'spec_helper'

RSpec.describe 'Adding multiple stack support to buildpack model', isolation: :truncation do
  let(:start_event_created_at) { Time.new(2017, 1, 1) }
  let(:tmp_migrations_dir) { Dir.mktmpdir }
  let(:pre_down_migration_stack) { VCAP::CloudController::Stack.make }

  before do
    VCAP::CloudController::Buildpack.make(name: 'a-great-buildpack-really', stack: nil)
    VCAP::CloudController::Buildpack.make(name: 'hwc_buildpack', stack: nil)
    FileUtils.cp(
      File.join(DBMigrator::SEQUEL_MIGRATIONS, '20180404165800_assign_stacks_to_buildpacks.rb'),
      tmp_migrations_dir,
    )
  end

  context 'STACKS_YML set to filepath specifying default stack' do
    let!(:original_env) { ENV['STACKS_YML'] }

    before do
      ENV['STACKS_YML'] = stacks_yml_path
      Sequel::Migrator.run(VCAP::CloudController::Buildpack.db, tmp_migrations_dir, table: :my_fake_table)
    end

    after { ENV['STACKS_YML'] = original_env }

    context 'STACKS_YML file does not define any windows stack' do
      let(:stacks_yml_path) { File.expand_path(File.join(File.dirname(__FILE__), '../fixtures/config/stacks.yml')) }

      it 'assigns the default stack to existing buildpacks' do
        expect(VCAP::CloudController::Buildpack.where(name: 'a-great-buildpack-really', stack: 'default-stack-name').count).to eq(1)
      end

      it 'assigns nil to the hwc_buildpack' do
        expect(VCAP::CloudController::Buildpack.where(name: 'hwc_buildpack', stack: nil).count).to eq(1)
      end
    end

    context 'STACKS_YML file defines windows2012R2 stack' do
      let(:stacks_yml_path) { File.expand_path(File.join(File.dirname(__FILE__), '../fixtures/config/stacks_windows2012R2.yml')) }

      it 'assigns the default stack to existing buildpacks' do
        expect(VCAP::CloudController::Buildpack.where(name: 'a-great-buildpack-really', stack: 'default-stack-name').count).to eq(1)
      end

      it 'assigns windows2012R2 to the hwc_buildpack' do
        expect(VCAP::CloudController::Buildpack.where(name: 'hwc_buildpack', stack: 'windows2012R2').count).to eq(1)
      end
    end

    context 'STACKS_YML file defines windows2016 stack' do
      let(:stacks_yml_path) { File.expand_path(File.join(File.dirname(__FILE__), '../fixtures/config/stacks_windows2016.yml')) }

      it 'assigns the default stack to existing buildpacks' do
        expect(VCAP::CloudController::Buildpack.where(name: 'a-great-buildpack-really', stack: 'default-stack-name').count).to eq(1)
      end

      it 'assigns windows2016 to the hwc_buildpack' do
        expect(VCAP::CloudController::Buildpack.where(name: 'hwc_buildpack', stack: 'windows2016').count).to eq(1)
      end
    end

    context 'STACKS_YML file defines windows 2012R2 and windows2016 stack' do
      let(:stacks_yml_path) { File.expand_path(File.join(File.dirname(__FILE__), '../fixtures/config/stacks_windows_all.yml')) }

      it 'assigns the default stack to existing buildpacks' do
        expect(VCAP::CloudController::Buildpack.where(name: 'a-great-buildpack-really', stack: 'default-stack-name').count).to eq(1)
      end

      it 'assigns windows2016 to the hwc_buildpack' do
        expect(VCAP::CloudController::Buildpack.where(name: 'hwc_buildpack', stack: 'windows2016').count).to eq(1)
      end
    end
  end

  context 'STACKS_YML not set' do
    it 'assigns nil stack to existing buildpacks' do
      Sequel::Migrator.run(VCAP::CloudController::Buildpack.db, tmp_migrations_dir, table: :my_fake_table)
      expect(VCAP::CloudController::Buildpack.where(name: 'a-great-buildpack-really', stack: nil).count).to eq(1)
      expect(VCAP::CloudController::Buildpack.where(name: 'hwc_buildpack', stack: nil).count).to eq(1)
    end
  end
end
