require 'spec_helper'
require 'actions/sidecar_synchronize_from_app_droplet'

module VCAP::CloudController
  RSpec.describe SidecarSynchronizeFromAppDroplet do
    describe '#synchronize' do
      let(:app) { AppModel.make(droplet: droplet, name: 'my_app', sidecar_guids: app_sidecars.map(&:guid)) }
      let(:droplet) do
        DropletModel.make(
          state: DropletModel::STAGED_STATE,
          sidecars: droplet_sidecars,
        )
      end

      let(:app_sidecars) { [] }
      let(:droplet_sidecars) { [{ name: 'sleepy-sidecar', command: 'sleep infinity', memory: 1000, process_types: ['web'] }] }

      context 'the app has no sidecars' do
        context 'when droplet has sidecars' do
          it 'creates the missing sidecars' do
            expect(app.processes.count).to eq(0)
            SidecarSynchronizeFromAppDroplet.synchronize(app)

            app.reload
            expect(app.sidecars.count).to eq(1), "sidecars: #{app.sidecars}"
            expect(app.sidecars.first.name).to eq('sleepy-sidecar')
            expect(app.sidecars.first.command).to eq('sleep infinity')
            expect(app.sidecars.first.memory).to eq(1000)
            expect(app.sidecars.first.process_types).to eq(['web'])
            expect(app.sidecars.first.origin).to eq('buildpack')
          end
        end

        context 'when the droplet has no sidecars' do
          let(:droplet) do
            DropletModel.make(
              state: DropletModel::STAGED_STATE,
              sidecars: nil,
            )
          end

          it 'neither errors nor creates sidecars' do
            expect(app.processes.count).to eq(0)
            SidecarSynchronizeFromAppDroplet.synchronize(app)

            app.reload
            expect(app.sidecars.count).to eq(0), "sidecars: #{app.sidecars}"
          end
        end
      end

      context 'the app has both origin-buildpack and origin-user sidecars' do
        let(:app_sidecars) do
          [
            SidecarModel.make(name: 'user-sidecar', origin: SidecarModel::ORIGIN_USER),
            SidecarModel.make(name: 'buildpack-sidecar', origin: SidecarModel::ORIGIN_BUILDPACK)
          ]
        end

        context 'when the droplet has sidecars' do
          it 'does not mess with the origin-user sidecars' do
            SidecarSynchronizeFromAppDroplet.synchronize(app)

            app.reload
            expect(app.sidecars.map(&:name)).to include('user-sidecar')
          end

          it 'replaces the origin-buildpack sidecars with the sidecars from the droplet' do
            SidecarSynchronizeFromAppDroplet.synchronize(app)

            app.reload
            expect(app.sidecars.map(&:name)).not_to include('buildpack-sidecar')
            expect(app.sidecars.map(&:name)).to include('sleepy-sidecar')
          end

          context 'but a droplet sidecar name matches an user-origin sidecar name' do
            let(:app_sidecars) do
              [
                SidecarModel.make(name: 'conflicted-sidecar', command: 'previous-sidecar-command', origin: SidecarModel::ORIGIN_USER)
              ]
            end

            let(:droplet_sidecars) do
              [{
                name: 'conflicted-sidecar',
                command: 'sleep infinity',
                process_types: ['web'],
                origin: SidecarModel::ORIGIN_BUILDPACK
              }]
            end

            it 'errors neatly' do
              expect do
                SidecarSynchronizeFromAppDroplet.synchronize(app)
              end.to raise_error(SidecarSynchronizeFromAppDroplet::ConflictingSidecarsError).
                with_message('Buildpack defined sidecar \'conflicted-sidecar\' conflicts with an existing user-defined sidecar. Consider renaming \'conflicted-sidecar\'.')
            end
          end

          context 'but a droplet sidecar name matches a buildpack-origin sidecar name' do
            let(:app_sidecars) do
              [
                SidecarModel.make(name: 'buildpack-sidecar', command: 'previous-buildpack-command', origin: SidecarModel::ORIGIN_BUILDPACK)
              ]
            end

            let(:droplet_sidecars) do
              [{
                name: 'buildpack-sidecar',
                command: 'sleep infinity',
                process_types: ['web'],
                origin: SidecarModel::ORIGIN_BUILDPACK
              }]
            end

            it 'replaces the origin-buildpack sidecars with the sidecars from the droplet' do
              SidecarSynchronizeFromAppDroplet.synchronize(app)

              app.reload
              expect(app.sidecars.map(&:name)).to include('buildpack-sidecar')
              expect(app.sidecars).to have_exactly(1).item
              expect(app.sidecars.first.command).to eq('sleep infinity')
            end
          end
        end

        context 'when the droplet has no sidecars' do
          let(:droplet_sidecars) { [] }

          it 'does not mess with the origin-user sidecars' do
            SidecarSynchronizeFromAppDroplet.synchronize(app)

            app.reload
            expect(app.sidecars.map(&:name)).to include('user-sidecar')
            expect(app.sidecars).to have_exactly(1).item
          end

          it 'removed all origin-buildpack sidecars' do
            SidecarSynchronizeFromAppDroplet.synchronize(app)

            app.reload
            expect(app.sidecars.map(&:name)).not_to include('buildpack-sidecar')
            expect(app.sidecars.map(&:name)).not_to include('sleepy-sidecar')
            expect(app.sidecars).to have_exactly(1).item
          end
        end
      end
    end
  end
end
