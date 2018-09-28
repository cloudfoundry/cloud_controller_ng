require 'spec_helper'
require 'cloud_controller/process_route_handler'

module VCAP::CloudController
  RSpec.describe ProcessRouteHandler do
    subject(:handler) { ProcessRouteHandler.new(process, runners) }
    let(:runners) { instance_double(Runners, runner_for_process: runner) }
    let(:runner) { instance_double(Diego::Runner, update_routes: nil) }

    describe '#update_route_information' do
      let!(:process) do
        ProcessModelFactory.make(diego: true).tap do |p|
          p.this.update(updated_at: Time.now - 1.day)
          p.reload
        end
      end

      it 'updates the version' do
        expect { handler.update_route_information }.to change { process.reload.updated_at }
      end

      context 'when perform_validation is not provided' do
        let(:db) { instance_double(Sequel::Database) }
        let(:process) { instance_double(ProcessModel, db: db) }

        it 'calls #save_changes with validate true' do
          allow(db).to receive_messages(in_transaction?: true, after_commit: nil)
          allow(process).to receive_messages(lock!: nil)

          expect(process).to receive(:set).with(updated_at: instance_of(Sequel::CurrentDateTimeTimestamp::Time))
          expect(process).to receive(:save_changes).with(hash_including(validate: true))

          handler.update_route_information
        end
      end

      context 'when perform_validation is false' do
        let(:db) { instance_double(Sequel::Database) }
        let(:process) { instance_double(ProcessModel, db: db) }

        it 'calls #save_changes with validate false' do
          allow(db).to receive_messages(in_transaction?: true, after_commit: nil)
          allow(process).to receive_messages(lock!: nil)

          expect(process).to receive(:set).with(updated_at: instance_of(Sequel::CurrentDateTimeTimestamp::Time))
          expect(process).to receive(:save_changes).with(hash_including(validate: false))

          handler.update_route_information(perform_validation: false)
        end
      end

      describe 'updating the backend' do
        let(:process) { ProcessModelFactory.make(state: 'STARTED') }

        it 'registers notify_backend_of_route_update for after_commit', isolation: :truncation do
          handler.update_route_information
          expect(runner).to have_received(:update_routes)
        end
      end
    end

    describe '#notify_backend_of_route_update' do
      context 'when the process does not exist' do
        let!(:process) { nil }

        it 'does not attempt to update routes' do
          expect { handler.notify_backend_of_route_update }.not_to raise_error
          expect(runner).not_to have_received(:update_routes)
        end
      end

      context 'when the process is started and staged' do
        let!(:process) { ProcessModelFactory.make(state: 'STARTED') }

        it 'updates the backend' do
          expect(process.state).to eq('STARTED')
          expect(process.package_state).to eq('STAGED')

          handler.notify_backend_of_route_update
          expect(runners).to have_received(:runner_for_process).with(process)
          expect(runner).to have_received(:update_routes)
        end
      end

      context 'when the app is started but not staged' do
        let!(:process) { ProcessModelFactory.make(state: 'STARTED') }

        before do
          process.current_droplet.destroy
        end

        it 'does not update the backend' do
          expect(process.state).to eq('STARTED')
          expect(process.package_state).to eq('PENDING')

          handler.notify_backend_of_route_update
          expect(runner).not_to have_received(:update_routes)
        end
      end

      context 'when the app is not started' do
        let!(:process) { ProcessModelFactory.make(state: 'STOPPED') }

        it 'does not update the backend' do
          expect(process.state).to eq('STOPPED')
          expect(process.package_state).to eq('STAGED')

          handler.notify_backend_of_route_update
          expect(runner).not_to have_received(:update_routes)
        end
      end

      context 'when there is a CannotCommunicateWithDiegoError' do
        let!(:process) { ProcessModelFactory.make(state: 'STARTED') }

        before do
          allow(runner).to receive(:update_routes).and_raise(Diego::Runner::CannotCommunicateWithDiegoError.new)
        end

        it 'logs the error and continues' do
          expect_any_instance_of(Steno::Logger).to receive(:error)
          expect { handler.notify_backend_of_route_update }.not_to raise_error
        end
      end
    end
  end
end
