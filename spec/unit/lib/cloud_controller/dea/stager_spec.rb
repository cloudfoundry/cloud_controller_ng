require 'spec_helper'

module VCAP::CloudController
  module Dea
    describe Stager do
      let(:config) do
        instance_double(Config)
      end

      let(:message_bus) do
        instance_double(CfMessageBus::MessageBus, publish: nil)
      end

      let(:dea_pool) do
        instance_double(Dea::Pool)
      end

      let(:stager_pool) do
        instance_double(Dea::StagerPool)
      end

      let(:runners) do
        instance_double(Runners)
      end

      let(:app) do
        App.new(guid: 'fake-app-guid')
      end

      let(:runner) { double(:Runner) }

      subject(:stager) do
        Stager.new(app, config, message_bus, dea_pool, stager_pool, runners)
      end

      describe '#stage' do
        let(:stager_task) do
          double(AppStagerTask)
        end

        before do
          allow(AppStagerTask).to receive(:new).and_return(stager_task)
          allow(stager_task).to receive(:stage).and_yield('fake-staging-result').and_return('fake-stager-response')
          allow(runners).to receive(:runner_for_app).with(app).and_return(runner)
          allow(runner).to receive(:start).with('fake-staging-result')

          stager.stage
        end

        it 'stages the app with a stager task' do
          expect(stager_task).to have_received(:stage)
          expect(AppStagerTask).to have_received(:new).with(config,
                                                            message_bus,
                                                            app,
                                                            dea_pool,
                                                            stager_pool,
                                                            an_instance_of(CloudController::Blobstore::UrlGenerator))
        end

        it 'starts the app with the returned staging result' do
          expect(runner).to have_received(:start).with('fake-staging-result')
        end

        it 'records the stager response on the app' do
          expect(app.last_stager_response).to eq('fake-stager-response')
        end
      end
    end
  end
end
