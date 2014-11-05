require 'spec_helper'
require 'repositories/app_repository'

module VCAP::CloudController
  describe AppRepository do

    let(:valid_opts) { {} }
    let(:process_repository) { ProcessRepository.new }

    describe '#find_by_guid' do
      it 'find the app object by guid and returns a something' do
        app_model      = AppModel.make
        app_repository = AppRepository.new(process_repository)
        app            = app_repository.find_by_guid(app_model.guid)

        expect(app.guid).to eq(app_model.guid)
        expect(app.space_guid).to eq(app_model.space_guid)
        expect(app.processes).to eq([])
      end

      it 'returns nil when the app does not exist' do
        app_repository = AppRepository.new(process_repository)
        app = app_repository.find_by_guid('non-existant-guid')
        expect(app).to be_nil
      end
    end

    describe '#find_by_guid_for_update' do
      it 'find the app object by guid and yield a something' do
        yielded = false
        app_model      = AppModel.make
        app_repository = AppRepository.new(process_repository)
        app_repository.find_by_guid_for_update(app_model.guid) do |app|
          yielded = true
          expect(app.guid).to eq(app_model.guid)
          expect(app.space_guid).to eq(app_model.space_guid)
          expect(app.processes).to eq([])
        end

        expect(yielded).to be_truthy
      end
    end

    describe '#new_app' do
      it 'returns an something object that has not been persisted' do
        app_repository = AppRepository.new(process_repository)
        expect {
          app = app_repository.new_app(valid_opts)
          expect(app.guid).to eq(nil)
          expect(app.space_guid).to eq(nil)
          expect(app.processes).to eq(nil)
        }.to_not change { AppModel.count }
      end
    end

    describe '#persist!' do
      context 'when the desired app does not exist' do
        it 'persists the app data model' do
          app_repository = AppRepository.new(process_repository)
          expect {
            desired_app = app_repository.new_app(valid_opts)
            app = app_repository.persist!(desired_app)
            expect(app.guid).to_not be(nil)
            expect(app.space_guid).to eq(nil)
            expect(app.processes).to eq([])
          }.to change { AppModel.count }.by(1)
        end
      end
    end

    describe '#delete' do
      context 'when the app is persisted' do
        it 'deletes the persisted app' do
          app_repository = AppRepository.new(process_repository)
          app = app_repository.persist!(app_repository.new_app(valid_opts))
          expect {
            app_repository.find_by_guid_for_update(app.guid) do |app_to_delete|
              app_repository.delete(app_to_delete)
            end
          }.to change { AppModel.count }.by(-1)
          expect(app_repository.find_by_guid(app.guid)).to be_nil
        end
      end

      context 'when the app is not persisted' do
        it 'does nothing' do
          app_repository = AppRepository.new(process_repository)
          app = app_repository.new_app(valid_opts)
          expect {
            app_repository.delete(app)
          }.to_not change { AppModel.count }
          expect(app_repository.find_by_guid(app.guid)).to be_nil
        end
      end
    end

    context "#add_process" do
      context "when the process exists" do
        context "and it is not associated with an app" do
          it "associates the process with the given app" do
            process_model = AppFactory.make
            process = process_repository.find_by_guid(process_model.guid)
            app_repository = AppRepository.new(process_repository)
            app = app_repository.persist!(app_repository.new_app(valid_opts))

            app_repository.add_process!(app, process.guid)
            expect(app_repository.find_by_guid(app.guid).processes.map(&:guid)).to include(process.guid)
            expect(process_model.reload.app_guid).to eq(app.guid)
          end
        end
      end

      context "when the process does not exist" do
        it "raises an invalid association error" do
          app_repository = AppRepository.new(process_repository)
          app = app_repository.persist!(app_repository.new_app(valid_opts))

          expect {
            app_repository.add_process!(app, 'not-existent')
          }.to raise_error(AppRepository::InvalidProcessAssociation)
        end
      end
    end
  end
end

