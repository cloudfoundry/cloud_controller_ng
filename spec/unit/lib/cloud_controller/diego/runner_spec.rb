require 'spec_helper'

module VCAP::CloudController
  module Diego
    describe Runner do
      let(:messenger) { instance_double(Messenger) }
      let(:app) { AppFactory.make(state: 'STARTED') }
      let(:protocol) { instance_double(Diego::Traditional::Protocol, desire_app_message: {}) }
      let(:default_health_check_timeout) { 9999 }

      subject(:runner) { Runner.new(app, messenger, protocol, default_health_check_timeout) }

      before do
        allow(messenger).to receive(:send_desire_request)
      end

      describe '#scale' do
        context 'when the app is started' do
          it 'desires an app, relying on its state to convey the change' do
            expect(messenger).to receive(:send_desire_request).with(app, default_health_check_timeout)
            runner.scale
          end
        end

        context 'when the app has not been started' do
          let(:app) { AppFactory.make(state: 'STOPPED') }

          it 'does not desire an app and raises an exception' do
            expect(messenger).to_not receive(:send_desire_request)
            expect { runner.scale }.to raise_error(VCAP::Errors::ApiError, /App not started/)
          end
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
        end

        it 'sends a stop app request' do
          runner.stop
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
        context 'when the app is started' do
          it 'desires an app, relying on its state to convey the change' do
            expect(messenger).to receive(:send_desire_request).with(app, default_health_check_timeout)
            runner.update_routes
          end
        end

        context 'when the app has not been started' do
          let(:app) { AppFactory.make(state: 'STOPPED') }

          it 'does not desire an app and raises an exception' do
            expect(messenger).to_not receive(:send_desire_request)
            expect { runner.update_routes }.to raise_error(VCAP::Errors::ApiError, /App not started/)
          end
        end
      end

      describe '#desire_app_message' do
        it "gets the procotol's desire_app_message" do
          expect(runner.desire_app_message).to eq({})
          expect(protocol).to have_received(:desire_app_message).with(app, default_health_check_timeout)
        end
      end

      describe '#with_logging' do
        it 'raises a reasonable error if diego is not on' do
          expect do
            runner.with_logging { raise StandardError.new('getaddrinfo: Name or service not known') }
          end.to raise_error(Runner::CannotCommunicateWithDiegoError)
        end

        it 'raises a reasonable error if diego is not on' do
          expect do
            runner.with_logging { raise ArgumentError.new('Other Error') }
          end.to raise_error(ArgumentError)
        end
      end
    end
  end
end
