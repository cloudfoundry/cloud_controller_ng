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
          beet: 'formanova',
        }
      end
      let(:new_labels) do
        {
          release: 'stable',
          'seriouseats.com/potato' => 'mashed',
          fruit: 'strawberries',
        }
      end
      let(:new_annotations) do
        {
          potato: 'idaho',
        }
      end
      let(:body) do
        {
          metadata: {
            labels: new_labels,
            annotations: new_annotations,
          },
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
              { prefix: 'seriouseats.com', key: 'potato', value: 'mashed' },
                { prefix: nil, key: 'fruit', value: 'strawberries' },
                { prefix: nil, key: 'release', value: 'stable' },
              )
            expect(build).to have_annotations({ key: 'potato', value: 'idaho' })
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
              { prefix: nil, key: 'fruit', value: 'pears' },
                { prefix: nil, key: 'truck', value: 'hino' },
              )
            expect(build).to have_annotations(
              { key: 'potato', value: 'celandine' },
                { key: 'beet', value: 'formanova' },
              )
          end
        end

        context 'when metadata is specified' do
          let(:body) do
            {
              metadata: {
                labels: new_labels.merge(fruit: nil, newstuff: 'here'),
                annotations: new_annotations.merge(beet: nil, asparagus: 'crunchy'),
              },
            }
          end
          it 'updates some, deletes nils, leaves unspecified fields alone' do
            expect(message).to be_valid
            build_update.update(build, message)
            build.reload
            expect(build).to have_labels(
              { prefix: 'seriouseats.com', key: 'potato', value: 'mashed' },
                { prefix: nil, key: 'release', value: 'stable' },
                { prefix: nil, key: 'truck', value: 'hino' },
                { prefix: nil, key: 'newstuff', value: 'here' },
              )
            expect(build).to have_annotations(
              { key: 'potato', value: 'idaho' },
                { key: 'asparagus', value: 'crunchy' },
              )
          end
        end
      end

      context 'when updating state' do
        let(:build) { BuildModel.make(:kpack) }

        context 'when a build was successfully completed' do
          let(:body) do
            {
              state: 'STAGED',
              lifecycle: {
                type: 'kpack',
                data: {
                  image: 'some-fake-image:tag',
                  processTypes: {
                    foo: 'foo start',
                    bar: 'bar start',
                  },
                }
              }
            }
          end

          it 'updates the build state as STAGED and updates the droplet with correct metadata' do
            build_update.update(build, message)

            expect(build.state).to eq('STAGED')
            expect(build.droplet.state).to eq('STAGED')
            expect(build.droplet.docker_receipt_image).to eq('some-fake-image:tag')
            expect(build.droplet.process_types).to eq({ 'foo' => 'foo start', 'bar' => 'bar start' })
          end
        end

        context 'when the state is FAILED' do
          let(:body) do
            {
              state: 'FAILED',
              error: 'failed to stage build'
            }
          end

          it 'updates the state to FAILED' do
            build_update.update(build, message)
            expect(build.state).to eq 'FAILED'
            expect(build.error_description).to include 'failed to stage build'
          end
        end
      end
    end
  end
end
