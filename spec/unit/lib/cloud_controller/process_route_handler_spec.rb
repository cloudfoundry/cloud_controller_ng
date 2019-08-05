require 'spec_helper'
require 'cloud_controller/process_route_handler'

module VCAP::CloudController
  RSpec.describe ProcessRouteHandler do
    subject(:handler) { ProcessRouteHandler.new(process, runners) }
    let(:runners) { instance_double(Runners, runner_for_process: runner) }
    let(:runner) { instance_double(Diego::Runner, update_routes: nil) }
    let(:port_policy) { instance_double(PortsPolicy, validate: nil) }

    before do
      allow(PortsPolicy).to receive(:new).and_return(port_policy)
    end

    describe '#update_route_information' do
      let!(:process) do
        ProcessModelFactory.make(diego: true, ports: [1024, 2024]).tap do |p|
          p.this.update(updated_at: Time.now - 1.day)
          p.reload
        end
      end

      it 'updates the version and ports' do
        expect {
          handler.update_route_information(perform_validation: false, updated_ports: [3024])
        }.to change {
          process.reload.updated_at
        }.and change {
          process.reload.ports
        }.from([1024, 2024]).to([3024])
      end

      context 'when perform_validation is not provided' do
        let(:db) { instance_double(Sequel::Database) }
        let(:process) { instance_double(ProcessModel, db: db) }

        it 'calls #save_changes with validate true' do
          allow(db).to receive_messages(in_transaction?: true, after_commit: nil)
          allow(process).to receive_messages(lock!: nil, ports: [])

          expect(process).to receive(:set).with(
            updated_at: instance_of(Sequel::CurrentDateTimeTimestamp::Time),
            ports: []
          )
          expect(process).to receive(:save_changes).with(hash_including(validate: true))

          handler.update_route_information
        end
      end

      context 'when perform_validation is false' do
        let(:db) { instance_double(Sequel::Database) }
        let(:process) { instance_double(ProcessModel, db: db) }

        it 'calls #save_changes with validate false' do
          allow(db).to receive_messages(in_transaction?: true, after_commit: nil)
          allow(process).to receive_messages(lock!: nil, ports: [])

          expect(process).to receive(:set).with(
            updated_at: instance_of(Sequel::CurrentDateTimeTimestamp::Time),
            ports: []
          )
          expect(process).to receive(:save_changes).with(hash_including(validate: false))

          handler.update_route_information(perform_validation: false)
        end
      end

      context 'when the updated ports are nil' do
        let(:db) { instance_double(Sequel::Database) }
        let(:process) { instance_double(ProcessModel, db: db) }

        it 'sets the process ports to nil' do
          allow(db).to receive_messages(in_transaction?: true, after_commit: nil)
          allow(process).to receive_messages(lock!: nil, ports: [1234])

          expect(process).to receive(:set).with(
            updated_at: instance_of(Sequel::CurrentDateTimeTimestamp::Time),
            ports: nil
          )
          expect(process).to receive(:save_changes).with(hash_including(validate: false))

          handler.update_route_information(perform_validation: false, updated_ports: nil)
        end
      end

      context 'when the updated ports are false' do
        let(:db) { instance_double(Sequel::Database) }
        let(:process) { instance_double(ProcessModel, db: db) }

        it 'sets the process ports to what they are currently set to' do
          allow(db).to receive_messages(in_transaction?: true, after_commit: nil)
          allow(process).to receive_messages(lock!: nil, ports: [1234])

          expect(process).to receive(:set).with(
            updated_at: instance_of(Sequel::CurrentDateTimeTimestamp::Time),
            ports: [1234]
          )
          expect(process).to receive(:save_changes).with(hash_including(validate: false))

          handler.update_route_information(perform_validation: false, updated_ports: false)
        end
      end

      context 'when the updated ports are invalid' do
        before do
          allow(port_policy).to receive(:validate) do
            process.errors.add(:ports, 'Ports must be in the 1024-65535.')
            true
          end
        end

        it 'raises a validation error' do
          expect {
            handler.update_route_information(perform_validation: false, updated_ports: [-3024])
          }.to raise_error(Sequel::ValidationFailed, /Ports must be in the 1024-65535./)
        end
      end

      describe 'updating the backend' do
        let(:process) { ProcessModelFactory.make(state: 'STARTED') }

        before do
          allow(VCAP::CloudController::ProcessObserver).to receive(:updated)
        end

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
          process.desired_droplet.destroy
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
