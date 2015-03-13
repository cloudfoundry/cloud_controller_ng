require 'spec_helper'
require 'actions/app_start'

module VCAP::CloudController
  describe AppStart do
    let(:app_start) { AppStart.new }

    describe '#start' do
      let(:app_model) { AppModel.make(desired_state: 'STOPPED', desired_droplet_guid: droplet_guid) }
      let(:process1) { AppFactory.make(state: 'STOPPED') }
      let(:process2) { AppFactory.make(state: 'STOPPED') }

      before do
        app_model.add_process_by_guid(process1.guid)
        app_model.add_process_by_guid(process2.guid)
      end

      context 'when the desired_droplet does not exist' do
        let(:droplet_guid) { nil }

        it 'raises a DropletNotFound exception' do
          expect {
            app_start.start(app_model)
          }.to raise_error(AppStart::DropletNotFound)
        end
      end

      context 'when the desired_droplet exists' do
        let(:droplet) { DropletModel.make }
        let(:droplet_guid) { droplet.guid }

        it 'sets the desired state on the app' do
          app_start.start(app_model)
          expect(app_model.desired_state).to eq('STARTED')
        end

        context 'and the droplet has a package' do
          let(:droplet) { DropletModel.make(package_guid: package.guid) }
          let(:package) { PackageModel.make(package_hash: 'some-awesome-thing', state: PackageModel::READY_STATE) }

          it 'sets the package hash correctly on the process' do
            app_start.start(app_model)
            app_model.processes.each do |process|
              expect(process.package_hash).to eq(package.package_hash)
              expect(process.package_state).to eq('STAGED')
            end
          end
        end

        context 'and the droplet does not have a package' do
          it 'sets the package hash to unknown' do
            app_start.start(app_model)
            app_model.processes.each do |process|
              expect(process.package_hash).to eq('unknown')
              expect(process.package_state).to eq('STAGED')
            end
          end
        end

        it 'prepares the sub-processes of the app' do
          app_start.start(app_model)
          app_model.processes.each do |process|
            expect(process.needs_staging?).to eq(false)
            expect(process.started?).to eq(true)
            expect(process.state).to eq('STARTED')
          end
        end
      end
    end
  end
end
