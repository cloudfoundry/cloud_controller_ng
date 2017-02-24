require 'spec_helper'
require 'isolation_segment_delete'
require 'isolation_segment_assign'

module VCAP::CloudController
  RSpec.describe IsolationSegmentDelete do
    let(:isolation_segment_model) { IsolationSegmentModel.make }
    let(:shared_isolation_segment_model) { IsolationSegmentModel.first(guid: VCAP::CloudController::IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID) }
    let(:assigner) { IsolationSegmentAssign.new }

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

    context 'when the segment is assigned as an orgs default' do
      let(:org) { Organization.make }

      before do
        assigner.assign(isolation_segment_model, [org])
        org.update(default_isolation_segment_model: isolation_segment_model)
      end

      it 'raises an error' do
        expect {
          subject.delete(isolation_segment_model)
        }.to raise_error(VCAP::CloudController::IsolationSegmentDelete::AssociationNotEmptyError,
          'Revoke the Organization entitlements for your Isolation Segment.')
      end
    end

    context 'when the segment is assigned as a spaces default' do
      let(:org) { Organization.make }
      let(:space) { Space.make(organization: org) }

      before do
        assigner.assign(isolation_segment_model, [org])
        space.update(isolation_segment_model: isolation_segment_model)
      end

      it 'raises an error' do
        expect {
          subject.delete(isolation_segment_model)
        }.to raise_error(VCAP::CloudController::IsolationSegmentDelete::AssociationNotEmptyError,
          'Revoke the Organization entitlements for your Isolation Segment.')
      end
    end
  end
end
