require 'spec_helper'
require 'actions/sidecar_update'

module VCAP::CloudController
  RSpec.describe SidecarUpdate do
    let(:app_model) { AppModel.make }
    let(:params) do
      {
        name: 'sidecar-name',
        command: './start',
        process_types: ['web', 'worker']
      }
    end
    let(:message) { SidecarUpdateMessage.new(params) }
    let(:sidecar) do
      SidecarModel.make(
        name:          'my_sidecar',
        command:       'rackup',
        app:           app_model
      )
    end

    before do
      SidecarProcessTypeModel.make(type: 'other_worker', sidecar: sidecar)
    end

    describe '.update' do
      it 'updates a sidecar' do
        SidecarUpdate.update(sidecar, message)

        expect(sidecar.name).to eq('sidecar-name')
        expect(sidecar.command).to eq('./start')
        expect(sidecar.process_types).to eq(['web', 'worker'])
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

        it 'updates only name' do
          SidecarUpdate.update(sidecar, message)
          expect(sidecar.command).to eq 'new_command'

          expect(sidecar.name).to eq 'my_sidecar'
          expect(sidecar.process_types).to eq ['other_worker']
        end
      end

      context 'when partially updating process_types' do
        let(:params) do
          { process_types: ['my_new_worker', 'and_another'] }
        end

        it 'updates only name' do
          SidecarUpdate.update(sidecar, message)
          expect(sidecar.process_types).to eq ['and_another', 'my_new_worker']

          expect(sidecar.name).to eq 'my_sidecar'
          expect(sidecar.command).to eq 'rackup'
        end
      end
    end
  end
end
