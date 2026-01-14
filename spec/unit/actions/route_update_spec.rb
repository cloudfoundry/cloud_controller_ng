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
          VCAP::CloudController::FeatureFlag.make(name: 'hash_based_routing', enabled: true)
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

        context 'when updating only hash_header' do
          let(:body) do
            {
              options: {
                hash_header: 'X-New-Header'
              }
            }
          end

          it 'updates hash_header while keeping other options' do
            expect(message).to be_valid
            subject.update(route:, message:)
            route.reload
            expect(route.options).to include({ 'loadbalancing' => 'hash', 'hash_header' => 'X-New-Header', 'hash_balance' => '2.0' })
          end

          it 'notifies the backend' do
            expect(fake_route_handler).to receive(:notify_backend_of_route_update)
            subject.update(route:, message:)
          end
        end

        context 'when updating only hash_balance' do
          let(:body) do
            {
              options: {
                hash_balance: '3.5'
              }
            }
          end

          it 'updates hash_balance while keeping other options' do
            expect(message).to be_valid
            subject.update(route:, message:)
            route.reload
            expect(route.options).to include({ 'loadbalancing' => 'hash', 'hash_header' => 'foobar', 'hash_balance' => '3.5' })
          end

          it 'notifies the backend' do
            expect(fake_route_handler).to receive(:notify_backend_of_route_update)
            subject.update(route:, message:)
          end
        end

        context 'when updating both hash_header and hash_balance' do
          let(:body) do
            {
              options: {
                hash_header: 'X-Updated-Header',
                hash_balance: '5.0'
              }
            }
          end

          it 'updates both hash options while keeping loadbalancing' do
            expect(message).to be_valid
            subject.update(route:, message:)
            route.reload
            expect(route.options).to include({ 'loadbalancing' => 'hash', 'hash_header' => 'X-Updated-Header', 'hash_balance' => '5.0' })
          end

          it 'notifies the backend' do
            expect(fake_route_handler).to receive(:notify_backend_of_route_update)
            subject.update(route:, message:)
          end
        end

        context 'when setting hash_balance to null' do
          let(:body) do
            {
              options: {
                hash_balance: nil
              }
            }
          end

          it 'removes hash_balance while keeping other options' do
            expect(message).to be_valid
            subject.update(route:, message:)
            route.reload
            expect(route.options).to include({ 'loadbalancing' => 'hash', 'hash_header' => 'foobar' })
            expect(route.options).not_to have_key('hash_balance')
          end

          it 'notifies the backend' do
            expect(fake_route_handler).to receive(:notify_backend_of_route_update)
            subject.update(route:, message:)
          end
        end

        context 'when updating from hash to round-robin' do
          let(:body) do
            {
              options: {
                loadbalancing: 'round-robin'
              }
            }
          end

          it 'updates to round-robin and removes hash options' do
            expect(message).to be_valid
            subject.update(route:, message:)
            route.reload
            expect(route.options).to eq({ 'loadbalancing' => 'round-robin' })
            expect(route.options).not_to have_key('hash_header')
            expect(route.options).not_to have_key('hash_balance')
          end

          it 'notifies the backend' do
            expect(fake_route_handler).to receive(:notify_backend_of_route_update)
            subject.update(route:, message:)
          end
        end

        context 'when updating from hash to least-connection' do
          let(:body) do
            {
              options: {
                loadbalancing: 'least-connection'
              }
            }
          end

          it 'updates to least-connection and removes hash options' do
            expect(message).to be_valid
            subject.update(route:, message:)
            route.reload
            expect(route.options).to eq({ 'loadbalancing' => 'least-connection' })
            expect(route.options).not_to have_key('hash_header')
            expect(route.options).not_to have_key('hash_balance')
          end

          it 'notifies the backend' do
            expect(fake_route_handler).to receive(:notify_backend_of_route_update)
            subject.update(route:, message:)
          end
        end

        context 'when setting hash_header to null' do
          let(:body) do
            {
              options: {
                hash_header: nil
              }
            }
          end

          it 'raises an error because hash_header is required for hash loadbalancing' do
            expect(message).to be_valid
            expect do
              subject.update(route:, message:)
            end.to raise_error(RouteUpdate::Error, 'Hash header must be present when loadbalancing is set to hash.')
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

        context 'when hash_based_routing feature flag is enabled' do
          before do
            VCAP::CloudController::FeatureFlag.make(name: 'hash_based_routing', enabled: true)
          end

          context 'when updating to hash loadbalancing without hash_header' do
            let(:body) do
              {
                options: {
                  loadbalancing: 'hash'
                }
              }
            end

            it 'raises an error' do
              expect(message).to be_valid
              expect do
                subject.update(route:, message:)
              end.to raise_error(RouteUpdate::Error, 'Hash header must be present when loadbalancing is set to hash.')
            end
          end

          context 'when updating to hash loadbalancing with hash_header' do
            let(:body) do
              {
                options: {
                  loadbalancing: 'hash',
                  hash_header: 'X-User-ID'
                }
              }
            end

            it 'successfully updates to hash loadbalancing' do
              expect(message).to be_valid
              subject.update(route:, message:)
              route.reload
              expect(route.options).to include({ 'loadbalancing' => 'hash', 'hash_header' => 'X-User-ID' })
            end

            it 'notifies the backend' do
              expect(fake_route_handler).to receive(:notify_backend_of_route_update)
              subject.update(route:, message:)
            end
          end

          context 'when updating to hash loadbalancing with hash_header and hash_balance' do
            let(:body) do
              {
                options: {
                  loadbalancing: 'hash',
                  hash_header: 'X-Session-ID',
                  hash_balance: '2.5'
                }
              }
            end

            it 'successfully updates to hash loadbalancing with all options' do
              expect(message).to be_valid
              subject.update(route:, message:)
              route.reload
              expect(route.options).to include({ 'loadbalancing' => 'hash', 'hash_header' => 'X-Session-ID', 'hash_balance' => '2.5' })
            end

            it 'notifies the backend' do
              expect(fake_route_handler).to receive(:notify_backend_of_route_update)
              subject.update(route:, message:)
            end
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
