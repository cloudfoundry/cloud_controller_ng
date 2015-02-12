require 'spec_helper'
require 'repositories/process_repository'

module VCAP::CloudController
  describe ProcessRepository do
    let(:space_guid) { Space.make.guid }
    let(:stack_guid) { Stack.make.guid }
    subject(:repo) { ProcessRepository.new }
    let(:valid_opts) do
      {
        'name'                 => 'my-process',
        'memory'               => 256,
        'instances'            => 2,
        'disk_quota'           => 1024,
        'space_guid'           => space_guid,
        'stack_guid'           => stack_guid,
        'state'                => 'STOPPED',
        'command'              => 'the-command',
        'buildpack'            => 'http://the-buildpack.com',
        'health_check_timeout' => 100,
        'docker_image'         => nil,
        'environment_json'     => {},
        'type'                 => 'worker',
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

    describe 'find_for_show' do
      it 'it finds both the process and the associated space' do
        space_model = Space.make
        app = AppFactory.make(buildpack: 'http://the-buildpack.com', space: space_model)

        process, space = repo.find_for_show(app.guid)

        expect(process.guid).to eq(app.guid)
        expect(process.name).to eq(app.name)
        expect(process.memory).to eq(app.memory)
        expect(process.instances).to eq(app.instances)
        expect(process.disk_quota).to eq(app.disk_quota)
        expect(process.space_guid).to eq(app.space.guid)
        expect(process.stack_guid).to eq(app.stack.guid)
        expect(process.state).to eq(app.state)
        expect(process.command).to eq(app.command)
        expect(process.buildpack).to eq(app.buildpack.url)
        expect(process.health_check_timeout).to eq(app.health_check_timeout)
        expect(process.docker_image).to eq(app.docker_image)
        expect(process.environment_json).to eq(app.environment_json)

        expect(space).to eq(space_model)
      end

      it 'returns nil when the process does not exist' do
        process, space = repo.find_for_show('non-existant-guid')
        expect(process).to be_nil
        expect(space).to be_nil
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

    describe '#find_for_update' do
      context 'when the process exists' do
        context 'with an associated app' do
          it 'find the process object by guid and yields a process, space, and neighbor_processes' do
            space = Space.make

            process = AppFactory.make(buildpack: 'http://the-buildpack.com', space: space)
            neighbor_process = AppFactory.make(space: space)

            app = AppModel.make
            app.add_process_by_guid(process.guid)

            neighbor_process = AppFactory.make(space: space)
            app.add_process_by_guid(neighbor_process.guid)

            yielded = false
            expect(ProcessMapper).to receive(:map_model_to_domain).with(neighbor_process).ordered.and_call_original
            expect(ProcessMapper).to receive(:map_model_to_domain).with(process).ordered.and_call_original
            repo.find_for_update(process.guid) do |p, s, nps|
              yielded = true
              expect(p.guid).to eq(process.guid)
              expect(nps.size).to eq(1)
              expect(nps.first.guid).to eq(neighbor_process.guid)
              expect(s).to eq(space)
            end

            expect(yielded).to be_truthy
          end
        end

        context 'when no app is associated' do
          it 'returns an empty array for neighbor_processes' do
            space = Space.make

            process = AppFactory.make(buildpack: 'http://the-buildpack.com', space: space)

            yielded = false
            expect(ProcessMapper).to receive(:map_model_to_domain).with(process).ordered.and_call_original
            repo.find_for_update(process.guid) do |p, s, nps|
              yielded = true
              expect(nps).to be_empty
            end

            expect(yielded).to be_truthy
          end
        end
      end

      context 'when the process does not exist' do
        it 'yields nil for both the space and process' do
          yielded = false
          repo.find_for_update('bogus') do |p, s, nps|
            yielded = true
            expect(p).to be_nil
            expect(s).to be_nil
            expect(nps).to be_empty
          end
          expect(yielded).to be_truthy
        end
      end
    end

    describe '#find_for_delete' do
      context 'when the process exists' do
        context 'with an associated app' do
          it 'find the process object by guid and yields a process, space' do
            space = Space.make

            process = AppFactory.make(buildpack: 'http://the-buildpack.com', space: space)

            app = AppModel.make
            app.add_process_by_guid(process.guid)

            yielded = false
            expect(ProcessMapper).to receive(:map_model_to_domain).with(process).ordered.and_call_original
            repo.find_for_update(process.guid) do |p, s|
              yielded = true
              expect(p.guid).to eq(process.guid)
              expect(s).to eq(space)
            end

            expect(yielded).to be_truthy
          end
        end
      end

      context 'when the process does not exist' do
        it 'yields nil for both the space and process' do
          yielded = false
          repo.find_for_update('bogus') do |p, s|
            yielded = true
            expect(p).to be_nil
            expect(s).to be_nil
          end
          expect(yielded).to be_truthy
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
          expect(process.type).to eq('worker')
        }.to_not change { App.count }
      end
    end

    describe '#update!' do
      context 'when the desired process does not exist' do
        it 'raises a ProcessNotFound error' do
          process_model      = AppFactory.make
          process_repository = ProcessRepository.new
          process_repository.find_for_update(process_model.guid) do |initial_process|
            updated_process = initial_process.with_changes({ name: 'my-super-awesome-name' })
            process_model.destroy
            expect {
              process_repository.update!(updated_process)
            }.to raise_error(ProcessRepository::ProcessNotFound)
          end
        end
      end

      context 'when the process exists in the database' do
        let(:app) { AppFactory.make(package_state: 'STAGED') }

        it 'updates the existing process data model' do
          original_package_state = app.package_state
          process_repository     = ProcessRepository.new
          process_repository.find_for_update(app.guid) do |initial_process|
            updated_process = initial_process.with_changes({ 'name' => 'my-super-awesome-name' })

            expect {
              process_repository.update!(updated_process)
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

        context 'when the desired process is not valid' do
          it 'raises a InvalidProcess error' do
            invalid_opts = {
              'state' => 'INVALID',
            }
            process_repository = ProcessRepository.new
            expect {
              process_repository.find_for_update(app.guid) do |initial_process|
                desired_process = initial_process.with_changes(invalid_opts)

                expect {
                  process_repository.update!(desired_process)
                }.to_not change { App.count }
              end
            }.to raise_error(ProcessRepository::InvalidProcess)
          end
        end

        context 'and then the original process is deleted from the database' do
          it 'raises a ProcessNotFound error' do
            process_model      = AppFactory.make
            process_repository = ProcessRepository.new
            process_repository.find_for_update(process_model.guid) do |initial_process|
              updated_process = initial_process.with_changes({ name: 'my-super-awesome-name' })
              process_model.destroy
              expect {
                process_repository.update!(updated_process)
              }.to raise_error(ProcessRepository::ProcessNotFound)
            end
          end
        end
      end

      context 'when a lock is not held' do
        it 'raises a MutationAttemptWithoutALock error' do
          process_repository = ProcessRepository.new
          process_model      = AppFactory.make
          desired_app        = ProcessMapper.map_model_to_domain(process_model)

          expect {
            process_repository.update!(desired_app)
          }.to raise_error(ProcessRepository::MutationAttemptWithoutALock)
        end
      end
    end

    describe '#create!' do
      it 'persists the process to the database' do
        process_repository = ProcessRepository.new
        process = process_repository.new_process(valid_opts)

        expect {
          process_repository.create!(process)
        }.to change { App.count }.by(1)
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
              process_repository.create!(desired_process)
            }.to_not change { App.count }
          }.to raise_error(ProcessRepository::InvalidProcess)
        end
      end
    end

    describe '#delete' do
      context 'when the process is persisted' do
        it 'deletes by guid' do
          process_repository = ProcessRepository.new
          process = process_repository.create!(process_repository.new_process(valid_opts))
          expect {
            process_repository.find_for_delete(filter: { guid: process.guid }) do |process_to_delete|
              process_repository.delete(process_to_delete)
            end
          }.to change { App.count }.by(-1)
          expect(process_repository.find_by_guid(process.guid)).to be_nil
        end

        it 'deletes by app_guid' do
          process_repository = ProcessRepository.new
          process = process_repository.create!(process_repository.new_process(valid_opts))
          expect {
            process_repository.find_for_delete(filter: { app_guid: process.app_guid }) do |process_to_delete|
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
