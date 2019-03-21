require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RotateDatabaseKey do
    describe '#perform' do
      context 'rotation' do
        # Apps are an example of a single encrypted field
        let(:historical_app) { AppModel.make }
        let(:historical_app_with_no_environment) { AppModel.make }
        let(:app) { AppModel.make }
        let(:app_the_second) { AppModel.make }
        let(:app_new_key_label) { AppModel.make }
        let(:env_vars) { { 'environment' => 'vars', 'PORT' => 344, 'longstring' => 'x' * 4097 } } # PORT is invalid!
        let(:env_vars_2) { { 'vars' => 'environment' } }

        # Service bindings are an example of multiple encrypted fields
        let(:service_binding) { ServiceBinding.make }
        let(:service_binding_new_key_label) { ServiceBinding.make }
        let(:credentials) { { 'secret' => 'creds' } }
        let(:credentials_2) { { 'more' => 'secrets' } }

        # Service instances are an example of single table inheritance
        let(:service_instance) { ManagedServiceInstance.make }
        let(:service_instance_new_key_label) { ManagedServiceInstance.make }
        let(:instance_credentials) { { 'instance' => 'credentials' } }
        let(:instance_credentials_2) { { 'instance_credentials' => 'live here' } }

        let(:task) { TaskModel.make }
        let(:task_the_second) { TaskModel.make }

        let(:database_encryption_keys) { { old: 'old-key', new: 'new-key' } }

        before do
          # This setup is complicated and done in the before block rather
          # than just creating the models with the expected initial data
          # because the Encryptor is global and we have to carefully
          # tweak its idea of the current_encryption_key_label to simulate
          # data with data that was encrypted with older keys

          # These apps' encryption_key_labels will be NULL
          allow(Encryptor).to receive(:current_encryption_key_label) { nil }
          allow(Encryptor).to receive(:database_encryption_keys) { {} }

          historical_app_with_no_environment.environment_variables = nil
          historical_app_with_no_environment.save(validate: false)

          historical_app.environment_variables = env_vars
          historical_app.save(validate: false)

          allow(Encryptor).to receive(:current_encryption_key_label) { 'old' }
          allow(Encryptor).to receive(:database_encryption_keys) { database_encryption_keys }

          # These models' encryption_key_labels will be 'old'
          app.environment_variables = env_vars
          app.save(validate: false)

          app_the_second.environment_variables = env_vars
          app_the_second.save(validate: false)

          service_binding.credentials = credentials
          service_binding.save(validate: false)

          service_instance.credentials = instance_credentials
          service_instance.save(validate: false)

          task.environment_variables = env_vars
          task.save(validate: false)

          task_the_second.environment_variables = env_vars
          task_the_second.save(validate: false)

          allow(Encryptor).to receive(:current_encryption_key_label) { 'new' }

          # These models' encryption_key_labels will be 'new'
          app_new_key_label.environment_variables = env_vars_2
          app_new_key_label.save

          service_binding_new_key_label.credentials = credentials_2
          service_binding_new_key_label.save

          service_instance_new_key_label.credentials = instance_credentials_2
          service_instance_new_key_label.save

          allow(Encryptor).to receive(:encrypt).and_call_original
          allow(Encryptor).to receive(:decrypt).and_call_original
          allow(Encryptor).to receive(:encrypted_classes).and_return([
            'VCAP::CloudController::ServiceBinding',
            'VCAP::CloudController::AppModel',
            'VCAP::CloudController::ServiceInstance',
          ])
        end

        context 'no current encryption key label is set' do
          before do
            allow(Encryptor).to receive(:current_encryption_key_label).and_return(nil)
          end

          it 'raises an error' do
            expect {
              RotateDatabaseKey.perform(batch_size: 1)
            }.to raise_error(CloudController::Errors::ApiError, /Please set the desired encryption key/)
          end
        end

        it 'changes the key label of each model' do
          expect(historical_app_with_no_environment.encryption_key_label).to be_nil
          expect(historical_app.encryption_key_label).to be_nil
          expect(app.encryption_key_label).to eq('old')
          expect(service_binding.encryption_key_label).to eq('old')
          expect(service_instance.encryption_key_label).to eq('old')

          RotateDatabaseKey.perform(batch_size: 1)

          expect(historical_app_with_no_environment.reload.encryption_key_label).to eq('new')
          expect(historical_app.reload.encryption_key_label).to eq('new')
          expect(app.reload.encryption_key_label).to eq('new')
          expect(service_binding.reload.encryption_key_label).to eq('new')
          expect(service_instance.reload.encryption_key_label).to eq('new')
        end

        it 're-encrypts all encrypted fields with the new key for all rows' do
          expect(Encryptor).to receive(:encrypt).
            with(JSON.dump(nil), historical_app_with_no_environment.salt).exactly(:twice)

          expect(Encryptor).to receive(:encrypt).
            with(JSON.dump(env_vars), historical_app.salt).exactly(:twice)

          expect(Encryptor).to receive(:encrypt).
            with(JSON.dump(env_vars), app.salt).exactly(:twice)

          expect(Encryptor).to receive(:encrypt).
            with(JSON.dump(credentials), service_binding.salt).exactly(:twice)

          expect(Encryptor).to receive(:encrypt).
            with(JSON.dump(instance_credentials), service_instance.salt).exactly(:twice)

          RotateDatabaseKey.perform(batch_size: 1)
        end

        it 'does not change the decrypted value' do
          RotateDatabaseKey.perform(batch_size: 1)

          expect(historical_app_with_no_environment.environment_variables).to be_nil
          expect(historical_app.environment_variables).to eq(env_vars)
          expect(app.environment_variables).to eq(env_vars)
          expect(service_binding.credentials).to eq(credentials)
          expect(service_instance.credentials).to eq(instance_credentials)
        end

        it 'does not re-encrypt values that are already encrypted with the new label' do
          expect(Encryptor).not_to receive(:encrypt).
            with(JSON.dump(env_vars_2), app_new_key_label.salt)

          expect(Encryptor).not_to receive(:encrypt).
            with(JSON.dump(credentials_2), service_binding_new_key_label.salt)

          RotateDatabaseKey.perform(batch_size: 1)
        end

        context 'batching so we do not load entire tables into memory' do
          let(:app2) { AppModel.make }
          let(:app3) { AppModel.make }

          before do
            allow(Encryptor).to receive(:current_encryption_key_label) { 'old' }

            app2.environment_variables = { password: 'hunter2' }
            app2.save

            app3.environment_variables = { feature: 'activate' }
            app3.save

            allow(Encryptor).to receive(:current_encryption_key_label) { 'new' }
          end

          it 'rotates batches until everything is rotated' do
            expect(app.encryption_key_label).to eq('old')
            expect(app2.encryption_key_label).to eq('old')
            expect(app3.encryption_key_label).to eq('old')

            RotateDatabaseKey.perform(batch_size: 1)

            expect(app.reload.encryption_key_label).to eq('new')
            expect(app2.reload.encryption_key_label).to eq('new')
            expect(app3.reload.encryption_key_label).to eq('new')
          end
        end

        context 'race conditions' do
          context 'rotates the rest of the members, even if a member of the batch is deleted during a row operation' do
            RSpec.shared_examples 'a row operation' do |op, args=[]|
              it op.to_s do
                allow(Encryptor).to receive(:encrypted_classes).and_return([
                  'VCAP::CloudController::TaskModel',
                ])

                allow_any_instance_of(VCAP::CloudController::TaskModel).to receive(op) do |task|
                  task.delete
                  allow_any_instance_of(VCAP::CloudController::TaskModel).to receive(op).and_call_original
                  task.method(op).call(*args)
                end

                expect(task_the_second.encryption_key_label).to eq('old')

                RotateDatabaseKey.perform(batch_size: 3)

                task_the_second.reload
                expect(task_the_second.encryption_key_label).to eq('new')
                expect(task_the_second.environment_variables).to eq(env_vars)
              end
            end

            it_behaves_like('a row operation', :save, [{ validate: false }])
            it_behaves_like('a row operation', :lock!)
          end

          it 'does not roll-back simultaneous changes to models', isolation: :truncation do
            allow(Encryptor).to receive(:encrypted_classes).and_return([
              'VCAP::CloudController::TaskModel',
            ])

            task_the_second.delete
            expect(TaskModel.count).to eq(1), 'Test mocking requires that there be only a single task present'

            new_environment_variables = { 'fresh' => 'environment variables' }

            # Mocking the TaskModel#db method at this point allows us to inject some simulated API user activity after
            # the TaskModel instance has been loaded by the Rotator, but before it locks the row
            allow_any_instance_of(TaskModel).to receive(:db) do |task_model|
              # Unstub the db method so that future calls do not get caught up in here
              allow_any_instance_of(TaskModel).to receive(:db).and_call_original

              # Opening a new db connection outside of the scope of the key rotator to simulate api user activity
              # while the rotator errand is running. We do this in a separate thread to ensure that the database connection
              # is distinct from the db connection that `RotateDatabaseKey.perform` is using, not to attempt to update
              # the TaskModel concurrently
              Thread.new {
                encrypted_new_env_vars = TaskModel.make(salt: task_model.salt, environment_variables: new_environment_variables).environment_variables_without_encryption
                db = Sequel.connect(task_model.db.opts)
                db.run("UPDATE tasks SET encryption_key_label = 'new', encrypted_environment_variables = '#{encrypted_new_env_vars}' where guid = '#{task_model.guid}';")
              }.join

              task_model.method(:db).call
            end

            expect(task.encryption_key_label).to eq('old')

            RotateDatabaseKey.perform

            task.reload
            expect(task.encryption_key_label).to eq('new')
            expect(task.environment_variables).to eq(new_environment_variables)
          end
        end
      end

      describe 'logging' do
        let(:logger) { instance_double(Steno::Logger, info: nil, error: nil) }
        let!(:app) { AppModel.make }
        let!(:task) { TaskModel.make(app: app) }
        let!(:task_jr) { TaskModel.make(app: app) }
        let!(:task_the_third) { TaskModel.make(app: app) }

        before do
          allow(Steno).to receive(:logger).and_return(logger)
          allow(Encryptor).to receive(:encrypted_classes).and_return([
            'VCAP::CloudController::TaskModel',
            'VCAP::CloudController::AppModel',
          ])
          allow(Encryptor).to receive(:current_encryption_key_label) { 'current' }
          allow(Encryptor).to receive(:database_encryption_keys) { { 'current' => 'thing' } }
        end

        it 'logs the total number of rows to be rotated' do
          RotateDatabaseKey.perform(batch_size: 1)

          expect(logger).to have_received(:info).with('3 rows of VCAP::CloudController::TaskModel are not encrypted with the current key and will be rotated')
        end

        it 'logs the number of rows as they are rotated' do
          RotateDatabaseKey.perform(batch_size: 2)

          expect(logger).to have_received(:info).with('Rotated batch of 2 rows of VCAP::CloudController::TaskModel')
          expect(logger).to have_received(:info).with('Rotated batch of 1 rows of VCAP::CloudController::TaskModel')
        end

        context 'when an unexpected error occurs while updating a record' do
          before do
            allow_any_instance_of(AppModel).to receive(:save).and_raise(StandardError.new('nooooooooo!!!'))
          end

          it 'logs information about the record and re-raises the error' do
            expect {
              RotateDatabaseKey.perform
            }.to raise_error(StandardError, 'nooooooooo!!!')
            expect(logger).to have_received(:error).with("Error 'StandardError' occurred while updating record: #{app.class}, id: #{app.id}")
          end
        end
      end
    end
  end
end
