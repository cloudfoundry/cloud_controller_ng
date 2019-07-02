require 'spec_helper'
require 'actions/sidecar_update'

module VCAP::CloudController
  RSpec.describe SidecarUpdate do
    let(:app) { AppModel.make }
    let(:params) do
      {
        name: 'sidecar-name',
        command: './start',
        process_types: ['web', 'worker'],
        memory_in_mb: 321
      }
    end
    let(:message) { SidecarUpdateMessage.new(params) }
    let(:sidecar) do
      SidecarModel.make(
        name:          'my_sidecar',
        command:       'rackup',
        app:           app,
        memory:        123,
      )
    end
    let!(:process) { ProcessModel.make(app: app, memory: 500, type: 'other_worker') }

    before do
      SidecarProcessTypeModel.make(type: 'other_worker', sidecar: sidecar)
    end

    describe '.update' do
      it 'updates a sidecar' do
        SidecarUpdate.update(sidecar, message)

        expect(sidecar.name).to eq('sidecar-name')
        expect(sidecar.command).to eq('./start')
        expect(sidecar.process_types).to eq(['web', 'worker'])
        expect(sidecar.memory).to eq(321)
      end

      context 'when partially updating name' do
        let(:params) do
          { name: 'new_name' }
        end

        it 'updates only name' do
          SidecarUpdate.update(sidecar, message)
          expect(sidecar.name).to eq 'new_name'

          expect(sidecar.command).to eq 'rackup'
          expect(sidecar.process_types).to eq ['other_worker']
        end
      end

      context 'when partially updating command' do
        let(:params) do
          { command: 'new_command' }
        end

        it 'updates only command' do
          SidecarUpdate.update(sidecar, message)
          expect(sidecar.command).to eq 'new_command'

          expect(sidecar.name).to eq 'my_sidecar'
          expect(sidecar.process_types).to eq ['other_worker']
        end
      end

      context 'when partially updating process_types' do
        let(:params) do
          { process_types: ['web', 'worker'] }
        end

        it 'updates only process_types' do
          SidecarUpdate.update(sidecar, message)
          expect(sidecar.process_types).to eq ['web', 'worker']

          expect(sidecar.name).to eq 'my_sidecar'
          expect(sidecar.command).to eq 'rackup'
        end

        context 'memory allocation' do
          let!(:new_worker_process) { ProcessModel.make(app: app, memory: 100, type: 'worker') }

          it 'raises InvalidSidecar when the memory allocated for the sidecar exceeds the memory allocated for the associated process' do
            expect {
              SidecarUpdate.update(sidecar, message)
            }.to raise_error(
              SidecarUpdate::InvalidSidecar,
              'The memory allocation defined is too large to run with the dependent "worker" process'
            )
          end
        end
      end

      context 'sidecar memory allocation' do
        context 'the memory allocated for the sidecar equals the memory allocated for the associated process' do
          let(:params) do
            {
              memory_in_mb: 500
            }
          end

          it 'raises InvalidSidecar' do
            expect {
              SidecarUpdate.update(sidecar, message)
            }.to raise_error(
              SidecarUpdate::InvalidSidecar,
              'The memory allocation defined is too large to run with the dependent "other_worker" process'
            )
          end
        end

        context 'the memory allocated for the sidecar exceeds the memory allocated for the associated process' do
          let(:params) do
            {
              memory_in_mb: 600
            }
          end

          it 'raises InvalidSidecar' do
            expect {
              SidecarUpdate.update(sidecar, message)
            }.to raise_error(
              SidecarUpdate::InvalidSidecar,
              'The memory allocation defined is too large to run with the dependent "other_worker" process'
            )
          end
        end

        context 'the memory allocated for the total sidecars exceeds the memory allocated for the associated process' do
          let!(:first_sidecar) { SidecarModel.make(app_guid: app.guid, memory: 300) }
          let!(:sptm) { SidecarProcessTypeModel.make(type: process.type, sidecar_guid: first_sidecar.guid, app_guid: app.guid) }
          let(:params) do
            {
              memory_in_mb: 300
            }
          end

          it 'raises InvalidSidecar' do
            expect {
              SidecarUpdate.update(sidecar, message)
            }.to raise_error(
              SidecarUpdate::InvalidSidecar,
              'The memory allocation defined is too large to run with the dependent "other_worker" process'
            )
          end
        end

        context 'the memory allocated to the sidecar exceeds the memory allocated for the newly associated process' do
          let(:params) do
            {
              memory_in_mb: 600,
              process_types: ['totes_new'],
            }
          end
          let!(:totes_new_process) { ProcessModel.make(app: app, memory: 500, type: 'totes_new') }

          it 'raises InvalidSidecar' do
            expect {
              SidecarUpdate.update(sidecar, message)
            }.to raise_error(
              SidecarUpdate::InvalidSidecar,
              'The memory allocation defined is too large to run with the dependent "totes_new" process'
            )
          end
        end
      end
    end
  end
end
