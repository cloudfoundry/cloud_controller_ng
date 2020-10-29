require 'spec_helper'
require 'actions/route_update'
require 'messages/route_update_message'

module VCAP::CloudController
  RSpec.describe RouteUpdate do
    let(:old_labels) do
      {
        clothing: 'blouse',
        fruit: 'peach'
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
        cuisine: 'thai',
        'doordash.com/potato' => 'mashed',
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

    let(:message) { RouteUpdateMessage.new(body) }
    let(:route) { Route.make }

    subject { RouteUpdate.new }
    describe '#update' do
      context 'when the route has no existing metadata' do
        context 'when no metadata is specified' do
          let(:body) do
            {}
          end

          it 'adds no metadata' do
            expect(message).to be_valid
            subject.update(route: route, message: message)
            route.reload
            expect(route.labels.size).to eq(0)
            expect(route.annotations.size).to eq(0)
          end
        end

        context 'when metadata is specified' do
          it 'updates the route metadata' do
            expect(message).to be_valid
            subject.update(route: route, message: message)

            route.reload
            expect(route).to have_labels(
              { prefix: 'doordash.com', key: 'potato', value: 'mashed' },
              { prefix: nil, key: 'fruit', value: 'strawberries' },
              { prefix: nil, key: 'cuisine', value: 'thai' },
            )
            expect(route).to have_annotations(
              { key: 'potato', value: 'idaho' }
            )
          end
        end
      end

      context 'when the route has existing metadata' do
        before do
          VCAP::CloudController::LabelsUpdate.update(route, old_labels, VCAP::CloudController::RouteLabelModel)
          VCAP::CloudController::AnnotationsUpdate.update(route, old_annotations, VCAP::CloudController::RouteAnnotationModel)
        end

        context 'when no metadata is specified' do
          let(:body) do
            {}
          end

          it 'adds no metadata' do
            expect(message).to be_valid
            subject.update(route: route, message: message)
            route.reload
            expect(route).to have_labels(
              { prefix: nil, key: 'fruit', value: 'peach' },
              { prefix: nil, key: 'clothing', value: 'blouse' },
            )
            expect(route).to have_annotations(
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
            subject.update(route: route, message: message)
            route.reload

            expect(route).to have_labels(
              { prefix: 'doordash.com', key: 'potato', value: 'mashed' },
              { prefix: nil, key: 'clothing', value: 'blouse' },
              { prefix: nil, key: 'newstuff', value: 'here' },
              { prefix: nil, key: 'cuisine', value: 'thai' },
            )
            expect(route).to have_annotations(
              { key: 'potato', value: 'idaho' },
              { key: 'asparagus', value: 'crunchy' },
            )
          end
        end
      end
    end
  end
end
