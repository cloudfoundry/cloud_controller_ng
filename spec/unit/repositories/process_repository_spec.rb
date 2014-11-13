require 'spec_helper'
require 'repositories/process_repository'

module VCAP::CloudController
  describe ProcessRepository do

    let(:space_guid) { Space.make.guid }
    let(:stack_guid) { Stack.make.guid }
    let(:valid_opts) do
      {
        name:                 'my-process',
        memory:               256,
        instances:            2,
        disk_quota:           1024,
        space_guid:           space_guid,
        stack_guid:           stack_guid,
        state:                'STOPPED',
        command:              'the-command',
        buildpack:            'http://the-buildpack.com',
        health_check_timeout: 100,
        docker_image:         nil,
        environment_json:     {},
      }
    end

    describe 'buildpack only returns custom buildpack information (until we need to handle buildpacks more explicitly)' do
      context 'when there is a custom buildpack' do
        it 'returns the custom buildpack' do
          app                = AppFactory.make(buildpack: 'http://the-buildpack.com')
          process_repository = ProcessRepository.new
          process            = process_repository.find_by_guid(app.guid)
          expect(process.buildpack).to eq('http://the-buildpack.com')
        end
      end

      context 'when there is an admin buildpack' do
        it 'returns nil' do
          app                = AppFactory.make
          process_repository = ProcessRepository.new
          process            = process_repository.find_by_guid(app.guid)
          expect(process.buildpack).to be_nil
        end
      end
    end

    describe '#find_by_guid' do
      it 'find the process object by guid and returns a process' do
        app                = AppFactory.make(buildpack: 'http://the-buildpack.com')
        process_repository = ProcessRepository.new
        process            = process_repository.find_by_guid(app.guid)
        expect(process.guid).to eq(app.guid)
        expect(process.name).to eq(app.name)
        expect(process.memory).to eq(app.memory)
        expect(process.instances).to eq(app.instances)
        expect(process.disk_quota).to eq(app.disk_quota)
        expect(process.space_guid).to eq(app.space.guid)
        expect(process.stack_guid).to eq(app.stack.guid)
        expect(process.state).to eq(app.state)
        expect(process.command).to eq(app.command)
        expect(process.buildpack).to eq('http://the-buildpack.com')
        expect(process.health_check_timeout).to eq(app.health_check_timeout)
        expect(process.docker_image).to eq(app.docker_image)
        expect(process.environment_json).to eq(app.environment_json)
      end

      it 'returns nil when the process does not exist' do
        process_repository = ProcessRepository.new
        process = process_repository.find_by_guid('non-existant-guid')
        expect(process).to be_nil
      end
    end

    describe '#find_by_guid_for_update' do
      it 'find the process object by guid and yield a process' do
        app                = AppFactory.make(buildpack: 'http://the-buildpack.com')
        process_repository = ProcessRepository.new
        process_repository.find_by_guid_for_update(app.guid) do |process|
          expect(process.guid).to eq(app.guid)
          expect(process.name).to eq(app.name)
          expect(process.memory).to eq(app.memory)
          expect(process.instances).to eq(app.instances)
          expect(process.disk_quota).to eq(app.disk_quota)
          expect(process.space_guid).to eq(app.space.guid)
          expect(process.stack_guid).to eq(app.stack.guid)
          expect(process.state).to eq(app.state)
          expect(process.command).to eq(app.command)
          expect(process.buildpack).to eq('http://the-buildpack.com')
          expect(process.health_check_timeout).to eq(app.health_check_timeout)
          expect(process.docker_image).to eq(app.docker_image)
          expect(process.environment_json).to eq(app.environment_json)
        end
      end
    end

    describe '#new_process' do
      it 'returns a process domain object that has not been persisted' do
        process_repository = ProcessRepository.new
        expect {
          process = process_repository.new_process(valid_opts)
          expect(process.guid).to be(nil)
          expect(process.name).to eq('my-process')
          expect(process.memory).to eq(256)
          expect(process.instances).to eq(2)
          expect(process.disk_quota).to eq(1024)
          expect(process.space_guid).to eq(space_guid)
          expect(process.stack_guid).to eq(stack_guid)
          expect(process.state).to eq('STOPPED')
          expect(process.command).to eq('the-command')
          expect(process.buildpack).to eq('http://the-buildpack.com')
          expect(process.health_check_timeout).to eq(100)
          expect(process.docker_image).to eq(nil)
          expect(process.environment_json).to eq({})
        }.to_not change { App.count }
      end
    end

    describe '#persist!' do
      context 'when the desired process does not exist' do
          it 'persists the process data model' do
            process_repository = ProcessRepository.new
            expect {
              desired_process = process_repository.new_process(valid_opts)
              process = process_repository.persist!(desired_process)
              expect(process.guid).to_not be(nil)
              expect(process.name).to eq('my-process')
              expect(process.memory).to eq(256)
              expect(process.instances).to eq(2)
              expect(process.disk_quota).to eq(1024)
              expect(process.space_guid).to eq(space_guid)
              expect(process.stack_guid).to eq(stack_guid)
              expect(process.state).to eq('STOPPED')
              expect(process.command).to eq('the-command')
              expect(process.buildpack).to eq('http://the-buildpack.com')
              expect(process.health_check_timeout).to eq(100)
              expect(process.docker_image).to eq(nil)
              expect(process.environment_json).to eq({})
            }.to change { App.count }.by(1)
          end
      end

      context 'when the process exists in the database' do
        it 'updates the existing process data model' do
          app                    = AppFactory.make(package_state: 'STAGED')
          original_package_state = app.package_state
          process_repository     = ProcessRepository.new
          process_repository.find_by_guid_for_update(app.guid) do |initial_process|
            updated_process = initial_process.with_changes({ name: 'my-super-awesome-name' })

            expect {
              process_repository.persist!(updated_process)
            }.not_to change { App.count }
            process = process_repository.find_by_guid(app.guid)

            expect(process.guid).to eq(app.guid)
            expect(process.name).to eq('my-super-awesome-name')
            expect(process.memory).to eq(app.memory)
            expect(process.instances).to eq(app.instances)
            expect(process.disk_quota).to eq(app.disk_quota)
            expect(process.space_guid).to eq(app.space.guid)
            expect(process.stack_guid).to eq(app.stack.guid)
            expect(process.state).to eq(app.state)
            expect(process.command).to eq(app.command)
            expect(process.buildpack).to be_nil
            expect(process.health_check_timeout).to eq(app.health_check_timeout)
            expect(process.docker_image).to eq(app.docker_image)
            expect(process.environment_json).to eq(app.environment_json)
            expect(app.reload.package_state).to eq(original_package_state)
          end
        end

        context 'and then the original process is deleted from the database' do
          it 'raises a ProcessNotFound error' do
            process_model      = AppFactory.make
            process_repository = ProcessRepository.new
            process_repository.find_by_guid_for_update(process_model.guid) do |initial_process|
              updated_process = initial_process.with_changes({ name: 'my-super-awesome-name' })
              process_model.destroy
              expect {
                process_repository.persist!(updated_process)
              }.to raise_error(ProcessRepository::ProcessNotFound)
            end
          end
        end
      end

      context 'when the desired process is not valid' do
        it 'raises a InvalidProcess error' do
          invalid_opts = {
            name: 'my-process',
          }
          process_repository = ProcessRepository.new
          expect {
            expect {
              desired_process = process_repository.new_process(invalid_opts)
              process_repository.persist!(desired_process)
            }.to_not change { App.count }
          }.to raise_error(ProcessRepository::InvalidProcess)
        end
      end
    end

    describe '#delete' do
      context 'when the process is persisted' do
        it 'deletes the persisted process' do
          process_repository = ProcessRepository.new
          process = process_repository.persist!(process_repository.new_process(valid_opts))
          expect {
            process_repository.find_by_guid_for_update(process.guid) do |process_to_delete|
              process_repository.delete(process_to_delete)
            end
          }.to change { App.count }.by(-1)
          expect(process_repository.find_by_guid(process.guid)).to be_nil
        end
      end

      context 'when the process is not persisted' do
        it 'does nothing' do
          process_repository = ProcessRepository.new
          process = process_repository.new_process(valid_opts)
          expect {
            process_repository.delete(process)
          }.to_not change { App.count }
          expect(process_repository.find_by_guid(process.guid)).to be_nil
        end
      end
    end
  end
end
