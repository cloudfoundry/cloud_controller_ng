require 'spec_helper'
require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::CloudController::Presenters::Mixins
  RSpec.describe MetadataPresentationHelpers do
    let(:dummy_class) { Class.new { include MetadataPresentationHelpers } }
    subject { dummy_class.new }
    let(:app) { FactoryBot.create(:app) }

    describe '#hashified_labels' do
      context 'when the list of labels is empty' do
        let(:labels) { [] }
        it 'returns an empty hash' do
          expect(subject.hashified_labels(labels)).to eq({})
        end
      end

      context 'when there are multiple labels' do
        let(:release_label) do
          VCAP::CloudController::AppLabelModel.make(
            key_name: 'release',
            value: 'stable',
            resource_guid: app.guid
          )
        end
        let(:potato_label) do
          VCAP::CloudController::AppLabelModel.make(
            key_prefix: 'maine.gov',
            key_name: 'potato',
            value: 'mashed',
            resource_guid: app.guid
          )
        end

        let(:labels) { [release_label, potato_label] }

        it 'returns a hash with the expected keys and values' do
          expect(subject.hashified_labels(labels)).to eq(
            'release' => 'stable',
            'maine.gov/potato' => 'mashed'
          )
        end
      end
    end

    describe '#hashified_annotations' do
      context 'when the list of annotations is empty' do
        let(:annotations) { [] }
        it 'returns an empty hash' do
          expect(subject.hashified_annotations(annotations)).to eq({})
        end
      end

      context 'when there are multiple annotations' do
        let(:philosophical_annotation) do
          VCAP::CloudController::AppAnnotationModel.make(
            resource_guid: app.guid,
            key: 'philosophy',
            value: 'All we are is dust in the wind, dude'
          )
        end
        let(:most_excellent_annotation) do
          VCAP::CloudController::AppAnnotationModel.make(
            resource_guid: app.guid,
            key: 'contacts',
            value: 'Bill tel(1111111) email(bill@s.preston), Test tel(222222) pager(3333333#555) email(theodore@logan)'
          )
        end

        let(:annotations) { [philosophical_annotation, most_excellent_annotation] }

        it 'returns a hash with the expected keys and values' do
          expect(subject.hashified_annotations(annotations)).to eq(
            'philosophy' => 'All we are is dust in the wind, dude',
            'contacts' => 'Bill tel(1111111) email(bill@s.preston), Test tel(222222) pager(3333333#555) email(theodore@logan)'
          )
        end
      end
    end
  end
end
