require 'spec_helper'
require 'repositories/app_repository'

module VCAP::CloudController
  describe AppRepository do

    let(:valid_opts) { { name: 'some-name' } }
    let(:process_repository) { ProcessRepository.new }

    describe '#find_by_guid' do
      it 'find the app object by guid and returns a something' do
        app_model      = AppModel.make
        app_repository = AppRepository.new
        app            = app_repository.find_by_guid(app_model.guid)

        expect(app.guid).to eq(app_model.guid)
        expect(app.name).to eq(app_model.name)
        expect(app.space_guid).to eq(app_model.space_guid)
        expect(app.processes).to eq([])
      end

      it 'returns nil when the app does not exist' do
        app_repository = AppRepository.new
        app = app_repository.find_by_guid('non-existant-guid')
        expect(app).to be_nil
      end
    end

    describe '#find_by_guid_for_update' do
      it 'find the app object by guid and yield a something' do
        yielded = false
        app_model      = AppModel.make
        app_repository = AppRepository.new
        app_repository.find_by_guid_for_update(app_model.guid) do |app|
          yielded = true
          expect(app.guid).to eq(app_model.guid)
          expect(app.name).to eq(app_model.name)
          expect(app.space_guid).to eq(app_model.space_guid)
          expect(app.processes).to eq([])
        end

        expect(yielded).to be_truthy
      end
    end

    describe '#new_app' do
      it 'returns an something object that has not been persisted' do
        app_repository = AppRepository.new
        expect {
          app = app_repository.new_app(valid_opts)
          expect(app.guid).to eq(nil)
          expect(app.name).to eq(valid_opts[:name])
          expect(app.space_guid).to eq(nil)
          expect(app.processes).to eq(nil)
        }.to_not change { AppModel.count }
      end
    end

    describe '#create!' do
      context 'when the desired app does not exist' do
        it 'creates the app data model' do
          app_repository = AppRepository.new
          expect {
            desired_app = app_repository.new_app(valid_opts)
            app = app_repository.create!(desired_app)
            expect(app.guid).to_not be(nil)
            expect(app.name).to eq(valid_opts[:name])
            expect(app.space_guid).to eq(nil)
            expect(app.processes).to eq([])
          }.to change { AppModel.count }.by(1)
        end
      end
    end

    describe '#update!' do
      context 'when the desired app does not exist' do
        it 'raises a AppNotFound error' do
          app_model      = AppModel.make
          app_repository = AppRepository.new

          app_repository.find_by_guid_for_update(app_model.guid) do |initial_app|
            updated_app = AppV3.new({
              guid:       initial_app.guid,
              name:       'my-super-awesome-name',
              processes:  initial_app.processes,
              space_guid: initial_app.space_guid,
            })

            app_model.destroy

            expect {
              app_repository.update!(updated_app)
            }.to raise_error(AppRepository::AppNotFound)
          end
        end
      end

      context 'when the app exists in the database' do
        let(:app) { AppModel.make }

        it 'updates the existing app and returns the domain model' do
          app_repository = AppRepository.new

          app_repository.find_by_guid_for_update(app.guid) do |initial_app|
            updated_app = AppV3.new({
              guid: initial_app.guid,
              name: 'my-super-awesome-name',
            })

            expect {
              result = app_repository.update!(updated_app)
              expect(result).to be_a(AppV3)
            }.not_to change { AppModel.count }

            app.reload

            expect(app.guid).to eq(initial_app.guid)
            expect(app.name).to eq('my-super-awesome-name')
          end
        end

        context 'when the desired app is not valid' do
          it 'raises a InvalidApp error' do
            app_repository = AppRepository.new

            app_repository.find_by_guid_for_update(app.guid) do |initial_app|
              updated_app = AppV3.new({ guid: initial_app.guid })

              allow_any_instance_of(AppModel).to receive(:save).and_raise(Sequel::ValidationFailed.new('some message'))
              expect {
                app_repository.update!(updated_app)
              }.to raise_error(AppRepository::InvalidApp, 'some message')
            end
          end
        end
      end

      context 'when a lock is not held' do
        it 'raises a MutationAttemptWithoutALock error' do
          app_repository = AppRepository.new
          app_model      = AppModel.make
          desired_app = AppV3.new({
            guid:       app_model.guid,
            name:       app_model.name,
            processes:  app_model.processes,
            space_guid: app_model.space_guid,
          })

          expect {
            app_repository.update!(desired_app)
          }.to raise_error(AppRepository::MutationAttemptWithoutALock)
        end
      end
    end

    describe '#delete' do
      context 'when the app exists' do
        it 'deletes the app' do
          app_repository = AppRepository.new
          app = app_repository.create!(app_repository.new_app(valid_opts))
          expect {
            app_repository.find_by_guid_for_update(app.guid) do |app_to_delete|
              app_repository.delete(app_to_delete)
            end
          }.to change { AppModel.count }.by(-1)
          expect(app_repository.find_by_guid(app.guid)).to be_nil
        end
      end

      context 'when the app does not exist' do
        it 'does nothing' do
          app_repository = AppRepository.new
          app = app_repository.new_app(valid_opts)
          expect {
            app_repository.delete(app)
          }.to_not change { AppModel.count }
          expect(app_repository.find_by_guid(app.guid)).to be_nil
        end
      end
    end

    context '#add_process!' do
      let(:app_repository) { AppRepository.new }
      let(:process_model) { AppFactory.make }
      let(:app) do
        app_repository.create!(app_repository.new_app(valid_opts))
      end
      let(:process) do
        process_repository.find_by_guid(process_model.guid)
      end

      context 'when the process exists' do
        context 'and it is not associated with an app' do
          it 'associates the process with the given app' do
            app_repository.find_by_guid_for_update(app.guid) do |app_to_update|
              app_repository.add_process!(app, process)
            end

            expect(app_repository.find_by_guid(app.guid).processes.map(&:guid)).to include(process.guid)
            expect(process_model.reload.app_guid).to eq(app.guid)
          end

          context 'and a lock has not been acquired' do
            it 'raises a locking error' do
              expect {
                app_repository.add_process!(app, process)
              }.to raise_error(AppRepository::MutationAttemptWithoutALock)
            end
          end
        end
      end

      context 'when the process does not exist' do
        it 'raises an invalid association error' do
          expect {
            app_repository.add_process!(app, AppProcess.new({}))
          }.to raise_error(AppRepository::InvalidProcessAssociation)
        end
      end
    end

    context '#remove_process!' do
      context 'when the process exists' do
        let(:app_repository) { AppRepository.new }
        let(:process_model) { AppFactory.make }
        let(:app) do
          app_repository.create!(app_repository.new_app(valid_opts))
        end
        let(:process) do
          process_repository.find_by_guid(process_model.guid)
        end

        context 'and it is associated with an app' do
          before do
            app_repository.find_by_guid_for_update(app.guid) do |app_to_update|
              app_repository.add_process!(app_to_update, process)
            end
          end

          context 'and a lock has not been acquired' do
            it 'raises an error' do
              expect {
                app_repository.remove_process!(app, process)
              }.to raise_error(AppRepository::MutationAttemptWithoutALock)
            end
          end

          it 'disassociates the process with the given app' do
            app_repository.find_by_guid_for_update(app.guid) do |app_to_update|
              app_repository.remove_process!(app_to_update, process)
            end

            expect(app_repository.find_by_guid(app.guid).processes).to eq([])
            expect(process_model.reload.app_guid).to eq(nil)
          end
        end
      end

      context 'when the process does not exist' do
        it 'raises an invalid association error' do
          app_repository = AppRepository.new
          app = app_repository.create!(app_repository.new_app(valid_opts))

          expect {
            app_repository.remove_process!(app, AppProcess.new({}))
          }.to raise_error(AppRepository::InvalidProcessAssociation)
        end
      end
    end
  end
end

