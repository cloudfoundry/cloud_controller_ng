require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RotateDatabaseKey do
    describe '#perform' do
      # Apps are an example of a single encrypted field
      let(:app) { AppModel.make }
      let(:app_the_second) { AppModel.make }
      let(:app_new_key_label) { AppModel.make }
      let(:env_vars) { { 'environment' => 'vars' } }
      let(:env_vars_2) { { 'vars' => 'environment' } }

      # Service bindings are an example of multiple encrypted fields
      let(:service_binding) { ServiceBinding.make }
      let(:service_binding_new_key_label) { ServiceBinding.make }
      let(:credentials) { { 'secret' => 'creds' } }
      let(:credentials_2) { { 'more' => 'secrets' } }
      let(:volume_mounts) { { 'volume' => 'mount' } }
      let(:volume_mounts_2) { { 'mount' => 'vesuvius' } }

      # Service instances are an example of single table inheritance
      let(:service_instance) { ManagedServiceInstance.make }
      let(:service_instance_new_key_label) { ManagedServiceInstance.make }
      let(:instance_credentials) { { 'instance' => 'credentials' } }
      let(:instance_credentials_2) { { 'instance_credentials' => 'live here' } }

      let(:task) { TaskModel.make }

      let(:database_encryption_keys) { { old: 'old-key', new: 'new-key' } }

      before do
        allow(Encryptor).to receive(:current_encryption_key_label) { 'old' }
        allow(Encryptor).to receive(:database_encryption_keys) { database_encryption_keys }

        app.environment_variables = env_vars
        app.save

        app_the_second.environment_variables = env_vars
        app_the_second.save

        service_binding.credentials = credentials
        service_binding.volume_mounts = volume_mounts
        service_binding.save

        service_instance.credentials = instance_credentials
        service_instance.save

        task.environment_variables = env_vars
        task.save

        allow(Encryptor).to receive(:current_encryption_key_label) { 'new' }

        app_new_key_label.environment_variables = env_vars_2
        app_new_key_label.save

        service_binding_new_key_label.credentials = credentials_2
        service_binding_new_key_label.volume_mounts = volume_mounts_2
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
        expect(app.encryption_key_label).to eq('old')
        expect(service_binding.encryption_key_label).to eq('old')
        expect(service_instance.encryption_key_label).to eq('old')

        RotateDatabaseKey.perform(batch_size: 1)

        expect(app.reload.encryption_key_label).to eq('new')
        expect(service_binding.reload.encryption_key_label).to eq('new')
        expect(service_instance.reload.encryption_key_label).to eq('new')
      end

      it 're-encrypts all encrypted fields with the new key for all rows' do
        expect(Encryptor).to receive(:encrypt).
          with(JSON.dump(env_vars), app.salt).exactly(:twice)

        expect(Encryptor).to receive(:encrypt).
          with(JSON.dump(credentials), service_binding.salt).exactly(:twice)

        expect(Encryptor).to receive(:encrypt).
          with(JSON.dump(volume_mounts), service_binding.volume_mounts_salt).exactly(:twice)

        expect(Encryptor).to receive(:encrypt).
          with(JSON.dump(instance_credentials), service_instance.salt).exactly(:twice)

        RotateDatabaseKey.perform(batch_size: 1)
      end

      it 'does not change the decrypted value' do
        RotateDatabaseKey.perform(batch_size: 1)

        expect(app.environment_variables).to eq(env_vars)
        expect(service_binding.credentials).to eq(credentials)
        expect(service_binding.volume_mounts).to eq(volume_mounts)
        expect(service_instance.credentials).to eq(instance_credentials)
      end

      it 'does not re-encrypt values that are already encrypted with the new label' do
        expect(Encryptor).not_to receive(:encrypt).
          with(JSON.dump(env_vars_2), app_new_key_label.salt)

        expect(Encryptor).not_to receive(:encrypt).
          with(JSON.dump(credentials_2), service_binding_new_key_label.salt)

        expect(Encryptor).not_to receive(:encrypt).
          with(JSON.dump(volume_mounts_2), service_binding_new_key_label.volume_mounts_salt)

        expect(Encryptor).not_to receive(:encrypt).
          with(JSON.dump(volume_mounts_2), service_instance.credentials)

        RotateDatabaseKey.perform(batch_size: 1)
      end

      describe 'batching so we do not load entire tables into memory' do
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

      describe 'race conditions' do
        context 'rotates the rest of the members, even if a member of the batch is deleted during a row operation' do
          RSpec.shared_examples 'a row operation' do |op|
            it op.to_s do
              allow(Encryptor).to receive(:encrypted_classes).and_return([
                'VCAP::CloudController::AppModel',
              ])

              allow_any_instance_of(VCAP::CloudController::AppModel).to receive(op) do |app|
                app.delete
                allow_any_instance_of(VCAP::CloudController::AppModel).to receive(op).and_call_original
                app.method(op).call
              end

              expect(app_the_second.encryption_key_label).to eq('old')

              RotateDatabaseKey.perform(batch_size: 3)

              app_the_second.reload
              expect(app_the_second.encryption_key_label).to eq('new')
              expect(app_the_second.environment_variables).to eq(env_vars)
            end
          end

          it_behaves_like('a row operation', :save)
          it_behaves_like('a row operation', :lock!)
        end

        it 'does not roll-back simultaneous changes to models', isolation: :truncation do
          allow(Encryptor).to receive(:encrypted_classes).and_return([
            'VCAP::CloudController::TaskModel',
          ])

          expect(TaskModel.count).to eq(1), 'Test mocking requires that there be only a single task present'

          new_environment_variables = { 'fresh' => 'environment variables' }
          allow_any_instance_of(TaskModel).to receive(:db) do |task_model|
            allow_any_instance_of(TaskModel).to receive(:db).and_call_original

            # Opening a new db connection outside of the scope of the key rotator to simulate api user activity
            # while the rotator errand is running
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
  end
end
