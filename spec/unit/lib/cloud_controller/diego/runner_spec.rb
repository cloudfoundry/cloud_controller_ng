require 'spec_helper'

module VCAP::CloudController
  module Diego
    describe Runner do
      let(:messenger) do
        instance_double(Messenger, send_desire_request: nil)
      end

      let(:app) do
        instance_double(App)
      end

      let(:protocol) do
        instance_double(Diego::Traditional::Protocol, desire_app_message: {})
      end

      subject(:runner) do
        Runner.new(app, messenger, protocol)
      end

      describe '#scale' do
        before do
          runner.scale
        end

        it 'desires an app, relying on its state to convey the change' do
          expect(messenger).to have_received(:send_desire_request).with(app)
        end
      end

      describe '#start' do
        before do
          runner.start
        end

        it 'desires an app, relying on its state to convey the change' do
          expect(messenger).to have_received(:send_desire_request).with(app)
        end
      end

      describe '#stop' do
        before do
          runner.stop
        end

        it 'desires an app, relying on its state to convey the change' do
          expect(messenger).to have_received(:send_desire_request).with(app)
        end
      end

      describe '#update_routes' do
        before do
          runner.update_routes
        end

        it 'desires an app, relying on its state to convey the change' do
          expect(messenger).to have_received(:send_desire_request).with(app)
        end
      end

      describe '#desire_app_message' do
        it "gets the procotol's desire_app_message" do
          expect(runner.desire_app_message).to eq({})
          expect(protocol).to have_received(:desire_app_message).with(app)
        end
      end
    end
  end
end
