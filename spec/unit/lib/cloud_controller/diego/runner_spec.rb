require 'spec_helper'

module VCAP::CloudController
  module Diego
    RSpec.describe Runner do
      let(:messenger) { instance_double(Messenger) }
      let(:process) { AppFactory.make(state: 'STARTED') }
      let(:protocol) { instance_double(Diego::Protocol, desire_app_message: {}) }
      let(:default_health_check_timeout) { 9999 }

      subject(:runner) { Runner.new(process, default_health_check_timeout) }

      before do
        runner.messenger = messenger
        allow(messenger).to receive(:send_desire_request)
      end

      describe '#scale' do
        context 'when the app is started' do
          it 'desires an app, relying on its state to convey the change' do
            expect(messenger).to receive(:send_desire_request).with(process, default_health_check_timeout)
            runner.scale
          end
        end

        context 'when the app has not been started' do
          let(:process) { AppFactory.make(state: 'STOPPED') }

          it 'does not desire an app and raises an exception' do
            expect(messenger).to_not receive(:send_desire_request)
            expect { runner.scale }.to raise_error(CloudController::Errors::ApiError, /App not started/)
          end
        end
      end

      describe '#start' do
        before do
          runner.start
        end

        it 'desires an app, relying on its state to convey the change' do
          expect(messenger).to have_received(:send_desire_request).with(process, default_health_check_timeout)
        end
      end

      describe '#stop' do
        before do
          allow(messenger).to receive(:send_stop_app_request)
        end

        it 'sends a stop app request' do
          runner.stop
          expect(messenger).to have_received(:send_stop_app_request)
        end
      end

      describe '#stop_index' do
        let(:index) { 0 }

        before do
          allow(messenger).to receive(:send_stop_index_request)
          runner.stop_index(index)
        end

        it 'stops the application instance with the specified index' do
          expect(messenger).to have_received(:send_stop_index_request).with(process, index)
        end
      end

      describe '#update_routes' do
        context 'when the app is started' do
          it 'desires an app, relying on its state to convey the change' do
            expect(messenger).to receive(:send_desire_request).with(process, default_health_check_timeout)
            runner.update_routes
          end
        end

        context 'when an app is in staging status' do
          let(:process) { AppFactory.make(state: 'STARTED') }

          before do
            DropletModel.make(app: process.app, package: process.latest_package, state: DropletModel::STAGING_STATE)
            process.reload
          end

          it 'should not update routes' do
            allow(messenger).to receive(:send_desire_request)

            runner.update_routes

            expect(messenger).to_not have_received(:send_desire_request)
          end
        end

        context 'when the app has not been started' do
          let(:process) { AppFactory.make(state: 'STOPPED') }

          it 'does not desire an app and raises an exception' do
            expect(messenger).to_not receive(:send_desire_request)
            expect { runner.update_routes }.to raise_error(CloudController::Errors::ApiError, /App not started/)
          end
        end
      end

      describe '#desire_app_message' do
        before do
          expect(Protocol).to receive(:new).and_return(protocol)
        end

        it "gets the procotol's desire_app_message" do
          expect(runner.desire_app_message).to eq({})
          expect(protocol).to have_received(:desire_app_message).with(process, default_health_check_timeout)
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

      describe '#messenger' do
        it 'creates a Diego::Messenger if not set' do
          runner.messenger = nil
          expected_messenger = double
          allow(Diego::Messenger).to receive(:new).and_return(expected_messenger)
          expect(runner.messenger).to eq(expected_messenger)
        end
      end
    end
  end
end
