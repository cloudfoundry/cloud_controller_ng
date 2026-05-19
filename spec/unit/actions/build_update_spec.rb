require 'spec_helper'
require 'actions/build_update'

module VCAP::CloudController
  RSpec.describe BuildUpdate do
    subject(:build_update) { BuildUpdate.new }

    describe '#update' do
      let(:old_labels) do
        {
          fruit: 'pears',
          truck: 'hino'
        }
      end
      let(:old_annotations) do
        {
          potato: 'celandine',
          beet: 'formanova'
        }
      end
      let(:new_labels) do
        {
          release: 'stable',
          'seriouseats.com/potato' => 'mashed',
          fruit: 'strawberries'
        }
      end
      let(:new_annotations) do
        {
          potato: 'idaho'
        }
      end
      let(:body) do
        {
          metadata: {
            labels: new_labels,
            annotations: new_annotations
          }
        }
      end
      let(:build) { BuildModel.make }
      let(:message) { BuildUpdateMessage.new(body) }

      context 'when there is no current metadata' do
        context 'when no metadata is specified' do
          let(:body) do
            {}
          end

          it 'adds no metadata' do
            expect(message).to be_valid
            build_update.update(build, message)
            build.reload
            expect(build.labels.size).to eq(0)
            expect(build.annotations.size).to eq(0)
          end
        end

        context 'when metadata is specified' do
          it 'updates the build metadata' do
            expect(message).to be_valid
            build_update.update(build, message)

            build.reload
            expect(build).to have_labels(
              { prefix: 'seriouseats.com', key_name: 'potato', value: 'mashed' },
              { prefix: nil, key_name: 'fruit', value: 'strawberries' },
              { prefix: nil, key_name: 'release', value: 'stable' }
            )
            expect(build).to have_annotations({ key_name: 'potato', value: 'idaho' })
          end
        end
      end

      context 'when the build has existing metadata' do
        before do
          VCAP::CloudController::LabelsUpdate.update(build, old_labels, VCAP::CloudController::BuildLabelModel)
          VCAP::CloudController::AnnotationsUpdate.update(build, old_annotations, VCAP::CloudController::BuildAnnotationModel)
        end

        context 'when no metadata is specified' do
          let(:body) do
            {}
          end

          it 'adds no metadata' do
            expect(message).to be_valid
            build_update.update(build, message)
            build.reload
            expect(build).to have_labels(
              { prefix: nil, key_name: 'fruit', value: 'pears' },
              { prefix: nil, key_name: 'truck', value: 'hino' }
            )
            expect(build).to have_annotations(
              { key_name: 'potato', value: 'celandine' },
              { key_name: 'beet', value: 'formanova' }
            )
          end
        end

        context 'when metadata is specified' do
          let(:body) do
            {
              metadata: {
                labels: new_labels.merge(fruit: nil, newstuff: 'here'),
                annotations: new_annotations.merge(beet: nil, asparagus: 'crunchy')
              }
            }
          end

          it 'updates some, deletes nils, leaves unspecified fields alone' do
            expect(message).to be_valid
            build_update.update(build, message)
            build.reload
            expect(build).to have_labels(
              { prefix: 'seriouseats.com', key_name: 'potato', value: 'mashed' },
              { prefix: nil, key_name: 'release', value: 'stable' },
              { prefix: nil, key_name: 'truck', value: 'hino' },
              { prefix: nil, key_name: 'newstuff', value: 'here' }
            )
            expect(build).to have_annotations(
              { key_name: 'potato', value: 'idaho' },
              { key_name: 'asparagus', value: 'crunchy' }
            )
          end
        end
      end
    end
  end
end
