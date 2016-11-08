require 'spec_helper'
require 'isolation_segment_delete'
require 'isolation_segment_assign'

module VCAP::CloudController
  RSpec.describe IsolationSegmentDelete do
    let(:isolation_segment_model) { IsolationSegmentModel.make }
    let(:shared_isolation_segment_model) { IsolationSegmentModel.first(guid: VCAP::CloudController::IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID) }

    it 'can delete isolation segments' do
      subject.delete(isolation_segment_model)
      expect {
        isolation_segment_model.reload
      }.to raise_error(Sequel::Error, 'Record not found')
    end

    it 'raises a 422 when deleteing the shared isolation segment' do
      expect {
        subject.delete(shared_isolation_segment_model)
      }.to raise_error /Cannot delete the #{shared_isolation_segment_model.name}/
    end

    context 'when the isolation segment has an organization' do
      let(:assigner) { IsolationSegmentAssign.new }
      let(:org) { Organization.make }

      before do
        assigner.assign(isolation_segment_model, [org])
        isolation_segment_model.reload
      end

      it 'raises an AssociationNotEmpty error' do
        expect {
          subject.delete(isolation_segment_model)
        }.to raise_error(CloudController::Errors::ApiError, /Please delete the Organization associations for your Isolation Segment/)
      end

      context 'when the isolation segment has been assigned a space' do
        before do
          Space.make(organization: org, isolation_segment_model: isolation_segment_model)
        end

        it 'raises an AssociationNotEmpty error' do
          expect {
            subject.delete(isolation_segment_model)
          }.to raise_error(CloudController::Errors::ApiError, /Please delete the Space associations for your Isolation Segment/)
        end
      end
    end
  end
end
