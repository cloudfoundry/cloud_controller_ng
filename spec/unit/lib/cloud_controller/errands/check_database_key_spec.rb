require 'spec_helper'

module VCAP::CloudController
  RSpec.describe CheckDatabaseKey do
    describe '#perform' do
      let(:logger) { instance_double(Steno::Logger, info: nil, error: nil) }

      before do
        allow(Steno).to receive(:logger).and_return(logger)
        allow(Encryptor).to receive_messages(
          encrypted_classes: ['VCAP::CloudController::AppModel', 'VCAP::CloudController::TaskModel'],
          current_encryption_key_label: 'current'
        )
      end

      context 'when no current encryption key label is set' do
        before do
          allow(Encryptor).to receive(:current_encryption_key_label).and_return(nil)
        end

        it 'exits with 1' do
          expect { CheckDatabaseKey.perform }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
        end

        it 'logs an error' do
          expect { CheckDatabaseKey.perform }.to raise_error(SystemExit)
          expect(logger).to have_received(:error).with('No current encryption key label is set')
        end
      end

      context 'when all rows are encrypted with the current key' do
        before do
          allow(AppModel).to receive(:exclude).and_return(double(or: double(count: 0)))
          allow(TaskModel).to receive(:exclude).and_return(double(or: double(count: 0)))
        end

        it 'exits with 0' do
          expect { CheckDatabaseKey.perform }.to raise_error(SystemExit) { |e| expect(e.status).to eq(0) }
        end

        it 'logs that all rows are current' do
          expect { CheckDatabaseKey.perform }.to raise_error(SystemExit)
          expect(logger).to have_received(:info).with('All rows are encrypted with the current key')
        end
      end

      context 'when rows need re-encryption' do
        before do
          allow(Encryptor).to receive(:current_encryption_key_label).and_return('old')
          allow(Encryptor).to receive(:database_encryption_keys).and_return({ old: 'old-key', current: 'current-key' })

          app = create(:app_model)
          app.environment_variables = { 'key' => 'value' }
          app.save(validate: false)

          task = create(:task_model)
          task.environment_variables = { 'key' => 'value' }
          task.save(validate: false)

          allow(Encryptor).to receive(:current_encryption_key_label).and_return('current')
        end

        it 'exits with 2' do
          expect { CheckDatabaseKey.perform }.to raise_error(SystemExit) { |e| expect(e.status).to eq(2) }
        end

        it 'logs the total number of rows needing re-encryption' do
          expect { CheckDatabaseKey.perform }.to raise_error(SystemExit)
          expect(logger).to have_received(:info).with(a_string_matching(/\d+ row\(s\) need re-encryption with the current key/))
        end
      end

      context 'when an unexpected error occurs' do
        before do
          allow(AppModel).to receive(:exclude).and_raise(StandardError.new('db connection failed'))
        end

        it 'exits with 1' do
          expect { CheckDatabaseKey.perform }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
        end

        it 'logs the error' do
          expect { CheckDatabaseKey.perform }.to raise_error(SystemExit)
          expect(logger).to have_received(:error).with('Unexpected error: StandardError: db connection failed')
        end
      end
    end
  end
end
