require 'spec_helper'
require 'models/runtime/helpers/package_state_calculator'

module VCAP::CloudController
  RSpec.describe 'PackageStateCalculator' do
    describe '#calculate' do
      let(:parent_app) { AppModel.make }
      let(:process) { ProcessModel.make(app: parent_app) }
      subject(:calculator) { PackageStateCalculator.new(process) }

      context 'when no package or droplet exists' do
        it 'is PENDING' do
          expect(process.latest_package).to be_nil
          expect(calculator.calculate).to eq('PENDING')
        end
      end

      context 'when the package failed to upload' do
        before do
          PackageModel.make(app: parent_app, state: PackageModel::FAILED_STATE)
        end

        it 'is FAILED' do
          expect(calculator.calculate).to eq('FAILED')
        end
      end

      context 'when the package is uploaded and there is no droplet or build for the app' do
        before do
          PackageModel.make(app: parent_app, package_hash: 'hash')
        end

        it 'is PENDING' do
          expect(calculator.calculate).to eq('PENDING')
        end
      end

      context 'when the package is uploaded and there is no CURRENT droplet' do
        before do
          build = BuildModel.make(app: parent_app, state: BuildModel::STAGED_STATE)
          DropletModel.make(app: parent_app, build: build, state: DropletModel::STAGED_STATE)
          PackageModel.make(app: parent_app, package_hash: 'hash')
          parent_app.update(droplet: nil)
        end

        it 'is PENDING' do
          expect(calculator.calculate).to eq('PENDING')
        end
      end

      context 'when the current droplet is the latest droplet' do
        before do
          package = PackageModel.make(app: parent_app, package_hash: 'hash', state: PackageModel::READY_STATE)
          build = BuildModel.make(app: parent_app, package: package, state: BuildModel::STAGED_STATE)
          droplet = DropletModel.make(app: parent_app, package: package, build: build, state: DropletModel::STAGED_STATE)
          parent_app.update(droplet: droplet)
        end

        it 'is STAGED' do
          expect(calculator.calculate).to eq('STAGED')
        end
      end

      context 'when the current droplet is not the latest droplet' do
        before do
          package = PackageModel.make(app: parent_app, package_hash: 'hash', state: PackageModel::READY_STATE)
          DropletModel.make(app: parent_app, package: package, state: DropletModel::STAGED_STATE)
        end

        it 'is PENDING' do
          expect(calculator.calculate).to eq('PENDING')
        end
      end

      context 'when the latest build failed to stage' do
        before do
          PackageModel.make(app: parent_app, package_hash: 'hash', state: PackageModel::READY_STATE)
          BuildModel.make(app: parent_app, state: BuildModel::FAILED_STATE)
        end

        it 'is FAILED' do
          expect(calculator.calculate).to eq('FAILED')
        end
      end

      context 'when the latest droplet failed to stage' do
        before do
          package = PackageModel.make(app: parent_app, package_hash: 'hash', state: PackageModel::READY_STATE)
          DropletModel.make(app: parent_app, package: package, state: DropletModel::FAILED_STATE)
        end

        it 'is FAILED' do
          expect(calculator.calculate).to eq('FAILED')
        end
      end

      context 'when there is a newer package than current droplet' do
        before do
          package = PackageModel.make(app: parent_app, package_hash: 'hash', state: PackageModel::READY_STATE)
          droplet = DropletModel.make(app: parent_app, package: package, state: DropletModel::STAGED_STATE)
          parent_app.update(droplet: droplet)
          PackageModel.make(app: parent_app, package_hash: 'hash', state: PackageModel::READY_STATE, created_at: droplet.created_at + 10.seconds)
        end

        it 'is PENDING' do
          expect(calculator.calculate).to eq('PENDING')
        end
      end

      context 'when the latest droplet is the current droplet but it does not have a package/build (e.g. droplet was uploaded)' do
        let(:droplet) { DropletModel.make(app: parent_app, state: DropletModel::STAGED_STATE, package: nil) }

        before do
          parent_app.update(droplet: droplet)
        end

        it 'is STAGED' do
          expect(calculator.calculate).to eq('STAGED')
        end
      end

      context 'when the latest droplet has no package but there is a previous package' do
        before do
          previous_package = PackageModel.make(app: parent_app, package_hash: 'hash', state: PackageModel::FAILED_STATE)
          droplet = DropletModel.make(app: parent_app, state: DropletModel::STAGED_STATE, created_at: previous_package.created_at + 10.seconds)
          parent_app.update(droplet: droplet)
        end

        it 'is STAGED' do
          expect(calculator.calculate).to eq('STAGED')
        end
      end
    end
  end
end
