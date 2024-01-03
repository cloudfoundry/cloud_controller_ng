require 'spec_helper'
require 'actions/annotation_delete'

module VCAP::CloudController
  RSpec.describe AnnotationDelete do
    subject(:annotation_delete) { AnnotationDelete }

    describe '#delete' do
      let!(:isolation_segment) { IsolationSegmentModel.make }
      let!(:annotation) { IsolationSegmentAnnotationModel.make(resource_guid: isolation_segment.guid, key_name: 'test1', value: 'bommel') }
      let!(:annotation2) { IsolationSegmentAnnotationModel.make(resource_guid: isolation_segment.guid, key_name: 'test2', value: 'bommel') }

      it 'deletes and cancels the annotation' do
        annotation_delete.delete([annotation, annotation2])

        expect(annotation.exists?).to be(false), 'Expected annotation to not exist, but it does'
        expect(annotation2.exists?).to be(false), 'Expected annotation2 to not exist, but it does'
      end
    end
  end
end
