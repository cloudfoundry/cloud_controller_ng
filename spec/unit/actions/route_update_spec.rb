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
        beet: 'formanova'
      }
    end
    let(:old_options) do
      '{"loadbalancing": "round-robin"}'
    end
    let(:new_labels) do
      {
        cuisine: 'thai',
        'doordash.com/potato' => 'mashed',
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

    let(:message) { RouteUpdateMessage.new(body) }
    let(:process) { ProcessModel.make }
    let(:route_mapping) { RouteMappingModel.make(app: process.app) }
    let(:route) { route_mapping.route }

    subject { RouteUpdate.new }
    describe '#update metadata' do
      before do
        expect(ProcessRouteHandler).not_to receive(:new)
      end

      context 'when the route has no existing metadata' do
        context 'when no metadata is specified' do
          let(:body) do
            {}
          end

          it 'adds no metadata' do
            expect(message).to be_valid
            subject.update(route:, message:)
            route.reload
            expect(route.labels.size).to eq(0)
            expect(route.annotations.size).to eq(0)
          end
        end

        context 'when metadata is specified' do
          it 'updates the route metadata' do
            expect(message).to be_valid
            subject.update(route:, message:)

            route.reload
            expect(route).to have_labels(
              { prefix: 'doordash.com', key_name: 'potato', value: 'mashed' },
              { prefix: nil, key_name: 'fruit', value: 'strawberries' },
              { prefix: nil, key_name: 'cuisine', value: 'thai' }
            )
            expect(route).to have_annotations(
              { key_name: 'potato', value: 'idaho' }
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
            subject.update(route:, message:)
            route.reload
            expect(route).to have_labels(
              { prefix: nil, key_name: 'fruit', value: 'peach' },
              { prefix: nil, key_name: 'clothing', value: 'blouse' }
            )
            expect(route).to have_annotations(
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
            subject.update(route:, message:)
            route.reload

            expect(route).to have_labels(
              { prefix: 'doordash.com', key_name: 'potato', value: 'mashed' },
              { prefix: nil, key_name: 'clothing', value: 'blouse' },
              { prefix: nil, key_name: 'newstuff', value: 'here' },
              { prefix: nil, key_name: 'cuisine', value: 'thai' }
            )
            expect(route).to have_annotations(
              { key_name: 'potato', value: 'idaho' },
              { key_name: 'asparagus', value: 'crunchy' }
            )
          end
        end
      end
    end

    describe '#update options' do
      let(:fake_route_handler) { instance_double(ProcessRouteHandler) }

      before do
        allow(ProcessRouteHandler).to receive(:new).with(process).and_return(fake_route_handler)
        allow(fake_route_handler).to receive(:notify_backend_of_route_update)
      end

      context 'when the route has no existing options' do
        context 'when no options are specified' do
          let(:body) do
            {}
          end

          it 'adds no options' do
            expect(message).to be_valid
            subject.update(route:, message:)
            route.reload
            expect(route.options).to eq({})
          end

          it 'does not notifies the backend' do
            expect(fake_route_handler).not_to receive(:notify_backend_of_route_update)
            subject.update(route:, message:)
          end
        end

        context 'when an option is specified' do
          let(:body) do
            {
              options: {
                loadbalancing: 'round-robin'
              }
            }
          end

          it 'adds the route option' do
            expect(message).to be_valid
            subject.update(route:, message:)
            route.reload
            expect(route[:options]).to eq('{"loadbalancing":"round-robin"}')
          end

          it 'notifies the backend' do
            expect(fake_route_handler).to receive(:notify_backend_of_route_update)
            subject.update(route:, message:)
          end
        end
      end

      context 'when the route has existing options for loadbalancing=hash' do
        before do
          route[:options] = '{"loadbalancing": "hash", "hash_header": "foobar", "hash_balance": "2"}'
        end

        context 'when the loadbalancing option value is set to null' do
          let(:body) do
            {
              options: {
                loadbalancing: nil
              }
            }
          end

          it 'removes this option and hash options' do
            expect(message).to be_valid
            subject.update(route:, message:)
            route.reload
            expect(route.options).to eq({})
          end

          it 'notifies the backend' do
            expect(fake_route_handler).to receive(:notify_backend_of_route_update)
            subject.update(route:, message:)
          end
        end

      end


      context 'when the route has existing option loadbalancing=round-robin' do
        before do
          route[:options] = '{"loadbalancing": "round-robin"}'
        end

        context 'when no options are specified' do
          let(:body) do
            {}
          end

          it 'modifies nothing' do
            expect(message).to be_valid
            subject.update(route:, message:)
            route.reload
            expect(route.options).to include({ 'loadbalancing' => 'round-robin' })
          end

          it 'does not notifies the backend' do
            expect(fake_route_handler).not_to receive(:notify_backend_of_route_update)
            subject.update(route:, message:)
          end
        end

        context 'when an option is specified' do
          let(:body) do
            {
              options: {
                loadbalancing: 'least-connection'
              }
            }
          end

          it 'updates the option' do
            expect(message).to be_valid
            subject.update(route:, message:)
            route.reload
            expect(route.options).to include({ 'loadbalancing' => 'least-connection' })
          end

          it 'notifies the backend' do
            expect(fake_route_handler).to receive(:notify_backend_of_route_update)
            subject.update(route:, message:)
          end
        end

        context 'when the option value is set to null' do
          let(:body) do
            {
              options: {
                loadbalancing: nil
              }
            }
          end

          it 'removes this option' do
            expect(message).to be_valid
            subject.update(route:, message:)
            route.reload
            expect(route.options).to eq({})
          end

          it 'notifies the backend' do
            expect(fake_route_handler).to receive(:notify_backend_of_route_update)
            subject.update(route:, message:)
          end
        end
      end
    end
  end
end
