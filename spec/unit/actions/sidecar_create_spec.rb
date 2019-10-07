require 'spec_helper'
require 'actions/sidecar_create'

module VCAP::CloudController
  RSpec.describe SidecarCreate do
    let(:app) { AppModel.make }
    let!(:process) { ProcessModel.make(app: app, memory: 500, type: 'web') }
    let(:params) do
      {
        name: 'sidecar-name',
        command: './start',
        process_types: ['web', 'worker'],
        memory_in_mb: 300,
      }
    end
    let(:message) { SidecarCreateMessage.new(params) }

    describe '.create' do
      it 'creates a sidecar for the app' do
        sidecar = nil
        expect {
          sidecar = SidecarCreate.create(app.guid, message)
        }.to change { SidecarModel.where(app: app).count }.by(1)

        expect(sidecar.app_guid).to eq(app.guid)
        expect(sidecar.name).to eq('sidecar-name')
        expect(sidecar.command).to eq('./start')
        expect(sidecar.process_types).to eq(['web', 'worker'])
        expect(sidecar.memory).to eq(300)
        expect(sidecar.origin).to eq('user')
      end

      context 'sidecar memory allocation' do
        context 'the memory allocated for the sidecar equals the memory allocated for the associated process' do
          let(:params) do
            {
              name: 'sidecar-name',
              command: './start',
              process_types: ['web', 'worker'],
              memory_in_mb: 500,
            }
          end

          it 'raises InvalidSidecar' do
            expect {
              SidecarCreate.create(app.guid, message)
            }.to raise_error(
              SidecarCreate::InvalidSidecar,
              'The memory allocation defined is too large to run with the dependent "web" process'
            )
          end
        end

        context 'the memory allocated for the sidecar exceeds the memory allocated for the associated process' do
          let(:params) do
            {
              name: 'sidecar-name',
              command: './start',
              process_types: ['web', 'worker'],
              memory_in_mb: 600,
            }
          end

          it 'raises InvalidSidecar' do
            expect {
              SidecarCreate.create(app.guid, message)
            }.to raise_error(
              SidecarCreate::InvalidSidecar,
              'The memory allocation defined is too large to run with the dependent "web" process'
            )
          end
        end

        context 'the memory allocated for the total sidecars exceeds the memory allocated for the associated process' do
          let!(:first_sidecar) { SidecarModel.make(app_guid: app.guid, memory: 300) }
          let!(:sptm) { SidecarProcessTypeModel.make(type: process.type, sidecar_guid: first_sidecar.guid, app_guid: app.guid) }
          let(:params) do
            {
              name: 'sidecar-name',
              command: './start',
              process_types: ['web', 'worker'],
              memory_in_mb: 300,
            }
          end

          it 'raises InvalidSidecar' do
            expect {
              SidecarCreate.create(app.guid, message)
            }.to raise_error(
              SidecarCreate::InvalidSidecar,
              'The memory allocation defined is too large to run with the dependent "web" process'
            )
          end
        end

        context 'there is no memory allocated for the sidecar' do
          let(:params) do
            {
              name: 'sidecar-name',
              command: './start',
              process_types: ['web', 'worker'],
            }
          end

          it 'creates a sidecar for the app with nil memory' do
            sidecar = nil
            expect {
              sidecar = SidecarCreate.create(app.guid, message)
            }.to change { SidecarModel.where(app: app).count }.by(1)

            expect(sidecar.app_guid).to eq(app.guid)
            expect(sidecar.name).to eq('sidecar-name')
            expect(sidecar.command).to eq('./start')
            expect(sidecar.process_types).to eq(['web', 'worker'])
            expect(sidecar.memory).to be_nil
          end
        end
      end
    end
  end
end
