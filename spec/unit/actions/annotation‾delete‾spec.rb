require 'spec_helper'
require 'actions/annotation_delete'

module VCAP::CloudController
  RSpec.describe AnnotationDelete do
    subject(:annotation_delete) { AnnotationDelete }

    describe '#delete' do
      let!(:annotation) { AppAnnotationModel.make }
      let!(:annotation2) { AppAnnotationModel.make }

      it 'deletes and cancels the annotation' do
        annotation_delete.delete([annotation, annotation2])

        expect(annotation.exists?).to eq(false), 'Expected annotation to not exist, but it does'
        expect(annotation2.exists?).to eq(false), 'Expected annotation2 to not exist, but it does'
      end
    end
  end
end
