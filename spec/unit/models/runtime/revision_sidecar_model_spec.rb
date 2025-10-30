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
                                                 types: %w[web worker]
                                               })
      end
    end

    describe 'revision_sidecar_process_types: #around_save' do
      it 'raises validation error on unique constraint violation for sidecar_process_types' do
        expect do
          expect(RevisionSidecarProcessTypeModel.where(revision_sidecar: revision_sidecar, type: 'web').count).to eq(1)
          RevisionSidecarProcessTypeModel.create(revision_sidecar: revision_sidecar, type: 'web', guid: SecureRandom.uuid)
        end.to raise_error(Sequel::ValidationFailed) { |error|
          expect(error.message).to include('Sidecar is already associated with process type web')
        }
      end

      it 'raises original error on other unique constraint violations' do
        expect do
          expect(RevisionSidecarProcessTypeModel.where(revision_sidecar: revision_sidecar, type: 'web').count).to eq(1)
          RevisionSidecarProcessTypeModel.create(revision_sidecar: revision_sidecar, type: 'worker',
                                                 guid: RevisionSidecarProcessTypeModel.where(revision_sidecar: revision_sidecar, type: 'web').first.guid)
        end.to raise_error(Sequel::UniqueConstraintViolation)
      end
    end
  end
end
