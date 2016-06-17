require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Dea::AppStarterTask do
    let(:num_service_instances) { 3 }
    let(:app) do
      AppFactory.make.tap do |app|
        num_service_instances.times do
          instance = ManagedServiceInstance.make(space: app.space)
          binding = ServiceBinding.make(
            app: app,
            service_instance: instance
          )
          app.add_service_binding(binding)
        end
      end
    end

    let(:dea_id) { 'dea_123' }
    let(:dea_ad) { create_ad(dea_id) }
    let(:abc_ad) { create_ad('abc') }
    let(:def_ad) { create_ad('def', 'https://host:1234') }
    let(:dea_pool) { double(:dea_pool) }

    let(:blobstore_url_generator) do
      double('blobstore_url_generator', droplet_download_url: 'app_uri')
    end

    let(:config) { TestConfig.config }

    let(:subject) { Dea::AppStarterTask.new(app, blobstore_url_generator, config) }

    def create_ad(id, url=nil)
      hash = { 'id' => id }
      hash['url'] = url if url
      Dea::NatsMessages::DeaAdvertisement.new(hash, nil)
    end

    before do
      allow(dea_pool).to receive(:mark_app_started)
      allow(dea_pool).to receive(:reserve_app_memory)
      allow(subject).to receive(:dea_pool).and_return(dea_pool)
      app.instances = 1
    end

    describe '#start' do
      context 'when the DEAs have sufficient capacity' do
        before do
          allow(dea_pool).to receive(:find_dea).and_return(dea_ad)
        end

        context 'when the app has 5 instances or fewer' do
          before do
            app.instances = 4
          end

          it 'starts all instances of the app' do
            expect(Dea::Client).to receive(:send_start).with(
              dea_ad,
              hash_including(
                index: 0,
              )
            ).ordered

            expect(Dea::Client).to receive(:send_start).with(
              dea_ad,
              hash_including(
                index: 1,
              )
            ).ordered

            expect(Dea::Client).to receive(:send_start).with(
              dea_ad,
              hash_including(
                index: 2,
              )
            ).ordered

            expect(Dea::Client).to receive(:send_start).with(
              dea_ad,
              hash_including(
                index: 3,
              )
            ).ordered

            subject.start
          end

          it 'starts the specified instances' do
            expect(Dea::Client).to receive(:send_start).with(
              dea_ad,
              hash_including(
                index: 1,
              )
            ).ordered

            expect(Dea::Client).to receive(:send_start).with(
              dea_ad,
              hash_including(
                index: 3,
              )
            ).ordered

            subject.start(specific_instances: [1, 3])
          end

          it 'starts the specified number of instances' do
            expect(dea_pool).to receive(:mark_app_started).exactly(3).times.with(dea_id: dea_id, app_id: app.guid)
            expect(dea_pool).to receive(:reserve_app_memory).exactly(3).times.with(dea_id, app.memory)

            expect(Dea::Client).to receive(:send_start).exactly(3).times.with(dea_ad, kind_of(Hash))

            subject.start(instances_to_start: 3)
          end
        end

        context 'when starting more than 5 instances' do
          before do
            app.instances = 9
          end

          it 'starts 5 at a time' do
            count = 0
            cb5 = lambda { expect(count).to eq 5 }
            cb9 = lambda { expect(count).to eq 9 }

            allow(subject).to receive(:start_instance_at_index) do
              count += 1
              count <= 5 ? cb5 : cb9
            end

            subject.start
          end
        end
      end

      context 'when the DEAs have insufficient capacity to start all of the instances' do
        before do
          app.instances = 4
          allow(dea_pool).to receive(:find_dea).and_return(nil, nil, dea_ad, dea_ad)
        end

        it 'starts instances for which capacity is available and raises an error' do
          expect(dea_pool).to receive(:mark_app_started).exactly(2).times.with(dea_id: dea_id, app_id: app.guid)
          expect(dea_pool).to receive(:reserve_app_memory).exactly(2).times.with(dea_id, app.memory)

          expect(Dea::Client).to receive(:send_start).with(
            dea_ad,
            hash_including(
              index: 2,
            )
          ).ordered

          expect(Dea::Client).to receive(:send_start).with(
            dea_ad,
            hash_including(
              index: 3,
            )
          ).ordered

          expect { subject.start }.to raise_error(CloudController::Errors::ApiError, 'One or more instances could not be started because of insufficient running resources.')
        end
      end

      context 'when the droplet is missing' do
        let(:blobstore_url_generator) { double('blobstore_url_generator', droplet_download_url: nil) }

        it 'raises an error' do
          expect { subject.start }.to raise_error(CloudController::Errors::ApiError, "The app package could not be found: #{app.guid}")
        end
      end

      context 'when no DEA is available' do
        before do
          allow(dea_pool).to receive(:find_dea).and_return(nil)
        end

        it 'raises an InsufficientRunningResourcesAvailable error' do
          expect(Dea::Client).to_not receive(:send_start)
          expect { subject.start }.to raise_error(CloudController::Errors::ApiError, 'One or more instances could not be started because of insufficient running resources.')
        end
      end
    end
  end
end
