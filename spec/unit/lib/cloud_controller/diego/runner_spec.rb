require 'spec_helper'

module VCAP::CloudController
  module Diego
    describe Runner do
      let(:messenger) { instance_double(Messenger) }
      let(:app) { instance_double(App) }
      let(:protocol) { instance_double(Diego::Traditional::Protocol, desire_app_message: {}) }
      let(:default_health_check_timeout) { 9999 }

      subject(:runner) { Runner.new(app, messenger, protocol, default_health_check_timeout) }

      before do
        allow(messenger).to receive(:send_desire_request)
      end

      describe '#scale' do
        before do
          runner.scale
        end

        it 'desires an app, relying on its state to convey the change' do
          expect(messenger).to have_received(:send_desire_request).with(app, default_health_check_timeout)
        end
      end

      describe '#start' do
        before do
          runner.start
        end

        it 'desires an app, relying on its state to convey the change' do
          expect(messenger).to have_received(:send_desire_request).with(app, default_health_check_timeout)
        end
      end

      describe '#stop' do
        before do
          allow(messenger).to receive(:send_stop_app_request)
          runner.stop
        end

        it 'sends a stop app request' do
          expect(messenger).to have_received(:send_stop_app_request).with(app)
        end
      end

      describe '#stop_index' do
        let(:index) { 0 }

        before do
          allow(messenger).to receive(:send_stop_index_request)
          runner.stop_index(index)
        end

        it 'stops the application instance with the specified index' do
          expect(messenger).to have_received(:send_stop_index_request).with(app, index)
        end
      end

      describe '#update_routes' do
        before do
          runner.update_routes
        end

        it 'desires an app, relying on its state to convey the change' do
          expect(messenger).to have_received(:send_desire_request).with(app, default_health_check_timeout)
        end
      end

      describe '#desire_app_message' do
        it "gets the procotol's desire_app_message" do
          expect(runner.desire_app_message).to eq({})
          expect(protocol).to have_received(:desire_app_message).with(app, default_health_check_timeout)
        end
      end
    end
  end
end
