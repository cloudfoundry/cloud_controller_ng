require 'spec_helper'

module VCAP::CloudController
  module Diego
    describe Messenger do
      let(:message_bus) { CfMessageBus::MockMessageBus.new }
      let(:staging_config) { TestConfig.config[:staging] }
      let(:protocol) { instance_double('Traditional::Protocol') }
      let(:instances) { 3 }
      let(:default_health_check_timeout) { 9999 }

      let(:app) do
        app = AppFactory.make
        app.instances = instances
        app.health_check_timeout = 120
        app
      end

      subject(:messenger) { Messenger.new(message_bus, protocol) }

      describe '#send_stage_request' do
        let(:subject) { 'staging_subject' }
        let(:message) { { staging: 'message' } }

        before do
          allow(protocol).to receive(:stage_app_request).and_return([subject, message])
        end

        it 'sends a nats message with the appropriate staging subject and payload' do
          messenger.send_stage_request(app, staging_config)

          expect(protocol).to have_received(:stage_app_request).with(app, staging_config)
          expect(message_bus.published_messages.size).to eq(1)

          nats_message = message_bus.published_messages.first
          expect(nats_message[:subject]).to eq(subject)
          expect(nats_message[:message]).to eq(message)
        end
      end

      describe '#send_desire_request' do
        let(:subject) { 'desire_subject' }
        let(:message) { { desire: 'message' } }

        before do
          allow(protocol).to receive(:desire_app_request).and_return([subject, message])
        end

        it 'sends a nats message with the appropriate subject and payload' do
          messenger.send_desire_request(app, default_health_check_timeout)

          expect(protocol).to have_received(:desire_app_request).with(app, default_health_check_timeout)
          expect(message_bus.published_messages.size).to eq(1)

          nats_message = message_bus.published_messages.first
          expect(nats_message[:subject]).to eq(subject)
          expect(nats_message[:message]).to eq(message)
        end
      end

      describe '#send_stop_staging_request' do
        let(:subject) { 'stop_staging_subject' }
        let(:message) { { stop_staging: 'message' } }
        let(:task_id) { 'task_id' }

        before do
          allow(protocol).to receive(:stop_staging_app_request).and_return([subject, message])
        end

        it 'sends a nats message with the appropriate subject and payload' do
          messenger.send_stop_staging_request(app, task_id)

          expect(protocol).to have_received(:stop_staging_app_request).with(app, task_id)
          expect(message_bus.published_messages.size).to eq(1)

          nats_message = message_bus.published_messages.first
          expect(nats_message[:subject]).to eq(subject)
          expect(nats_message[:message]).to eq(message)
        end
      end

      describe '#send_stop_index_request' do
        let(:subject) { 'stop_index_subject' }
        let(:message) { { stop_index: 'index' } }
        let(:index) { 3 }

        before do
          allow(protocol).to receive(:stop_index_request).and_return([subject, message])
        end

        it 'sends a nats message with the appropriate subject and payload' do
          messenger.send_stop_index_request(app, index)

          expect(protocol).to have_received(:stop_index_request).with(app, index)
          expect(message_bus.published_messages.size).to eq(1)

          nats_message = message_bus.published_messages.first
          expect(nats_message[:subject]).to eq(subject)
          expect(nats_message[:message]).to eq(message)
        end
      end
    end
  end
end
