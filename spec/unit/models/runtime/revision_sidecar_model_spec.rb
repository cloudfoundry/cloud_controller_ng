require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RevisionSidecarModel do
    let(:revision_sidecar) { RevisionSidecarModel.make }

    describe '#process_types' do
      it 'returns the names of associated sidecar_process_types' do
        RevisionSidecarProcessTypeModel.make(type: 'other worker', revision_sidecar: revision_sidecar)

        expect(revision_sidecar.process_types).to eq ['web', 'other worker'].sort
      end
    end

    describe '#to_hash' do
      let(:revision_sidecar) { RevisionSidecarModel.make(name: 'sleepy', command: 'sleep forever') }
      let!(:web_process_type) { RevisionSidecarProcessTypeModel.make(revision_sidecar: revision_sidecar, type: 'worker') }

      it 'returns a hash of attributes' do
        expect(revision_sidecar.to_hash).to eq({
            name: 'sleepy',
            command: 'sleep forever',
            types: ['web', 'worker']
        })
      end
    end
  end
end
