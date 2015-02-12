require 'spec_helper'
require 'handlers/processes_handler'

module VCAP::CloudController
  describe ProcessUpdateMessage do
    context 'when a name parameter is provided' do
      let(:body) { '{ "name": "my-name" }' }
      let(:guid) { 'my-guid' }

      it 'is not valid' do
        update_message = ProcessUpdateMessage.create_from_http_request(guid, body)
        errors = update_message.validate
        expect(errors).to include('The name field cannot be updated on a Process')
      end
    end

    context 'when nil opts are  provided' do
      let(:body) { nil }
      let(:guid) { 'my-guid' }

      it 'is not valid' do
        update_message = ProcessUpdateMessage.create_from_http_request(guid, body)
        errors = update_message.validate
        expect(errors).to include('Invalid Process')
      end
    end
  end

  describe ProcessesHandler do
    let(:security_context) { double(:sc, current_user: User.new(guid: '123'), current_user_email: 'user@user.com') }
    let(:process_repo) { double(:process_repo) }
    let(:process_event_repo) { double(:process_event_repo) }
    let(:space) { Space.make }
    let(:processes_handler) { ProcessesHandler.new(process_repo, process_event_repo) }
    let(:access_context) { double(:access_context) }

    describe '#list' do
      let!(:process1) { AppFactory.make(space: space) }
      let!(:process2) { AppFactory.make(space: space) }
      let(:user) { User.make }
      let(:page) { 1 }
      let(:per_page) { 1 }
      let(:options) { { page: page, per_page: per_page } }
      let(:pagination_options) { PaginationOptions.new(options) }
      let(:paginator) { double(:paginator) }
      let(:processes_handler) { described_class.new(process_repo, process_event_repo, paginator) }
      let(:roles) { double(:roles, admin?: admin_role) }
      let(:admin_role) { false }

      before do
        allow(access_context).to receive(:roles).and_return(roles)
        allow(access_context).to receive(:user).and_return(user)
        allow(paginator).to receive(:get_page)
      end

      context 'when the user is an admin' do
        let(:admin_role) { true }
        before do
          allow(access_context).to receive(:roles).and_return(roles)
          AppFactory.make
        end

        it 'allows viewing all processes' do
          processes_handler.list(pagination_options, access_context)
          expect(paginator).to have_received(:get_page) do |dataset, _|
            expect(dataset.count).to eq(3)
          end
        end
      end

      context 'when the user cannot list any processes' do
        it 'applies a user visibility filter properly' do
          processes_handler.list(pagination_options, access_context)
          expect(paginator).to have_received(:get_page) do |dataset, _|
            expect(dataset.count).to eq(0)
          end
        end
      end

      context 'when the user can list processes' do
        before do
          space.organization.add_user(user)
          space.add_developer(user)
        end

        it 'applies a user visibility filter properly' do
          processes_handler.list(pagination_options, access_context)
          expect(paginator).to have_received(:get_page) do |dataset, _|
            expect(dataset.count).to eq(2)
          end
        end

        it 'can filter by app_guid' do
          v3app = AppModel.make
          process1.app_guid = v3app.guid
          process1.save

          filter_options = { app_guid: v3app.guid }

          processes_handler.list(pagination_options, access_context, filter_options)

          expect(paginator).to have_received(:get_page) do |dataset, _|
            expect(dataset.count).to eq(1)
          end
        end
      end
    end

    describe '#raw_list' do
      let!(:process1) { AppFactory.make(space: space, type: 'p1') }
      let!(:process2) { AppFactory.make(space: space, type: 'p2') }
      let(:user) { User.make }
      let(:paginator) { double(:paginator) }
      let(:processes_handler) { described_class.new(process_repo, process_event_repo, paginator) }
      let(:roles) { double(:roles, admin?: admin_role) }
      let(:admin_role) { false }

      before do
        allow(access_context).to receive(:roles).and_return(roles)
        allow(access_context).to receive(:user).and_return(user)
      end

      context 'when the user is an admin' do
        let(:admin_role) { true }
        before do
          allow(access_context).to receive(:roles).and_return(roles)
          AppFactory.make
        end

        it 'allows viewing all processes' do
          dataset = processes_handler.raw_list(access_context)
          expect(dataset.count).to eq(3)
        end
      end

      context 'when the user cannot list any processes' do
        it 'applies a user visibility filter properly' do
          dataset = processes_handler.raw_list(access_context)
          expect(dataset.count).to eq(0)
        end
      end

      context 'when the user can list processes' do
        before do
          space.organization.add_user(user)
          space.add_developer(user)
        end

        it 'applies a user visibility filter properly' do
          dataset = processes_handler.raw_list(access_context)
          expect(dataset.count).to eq(2)
        end

        it 'can filter by app_guid' do
          v3app = AppModel.make
          process1.app_guid = v3app.guid
          process1.save

          filter_options = { app_guid: v3app.guid }

          dataset = processes_handler.raw_list(access_context, filter: filter_options)
          expect(dataset.count).to eq(1)
        end

        it 'can filter by type' do
          filter_options = { type: process2.type }

          dataset = processes_handler.raw_list(access_context, filter: filter_options)
          expect(dataset.count).to eq(1)
          expect(dataset.all).to include(process2)
        end

        it 'rejects random filters' do
          filter_options = { guid: process2.guid }

          dataset = processes_handler.raw_list(access_context, filter: filter_options)
          expect(dataset.count).to eq(2)
        end

        it 'can exclude types' do
          exclude_options = { type: process2.type }

          dataset = processes_handler.raw_list(access_context, exclude: exclude_options)
          expect(dataset.count).to eq(1)
          expect(dataset.all).to include(process1)
        end

        it 'rejects random exclusions' do
          exclude_options = { guid: process2.guid }

          dataset = processes_handler.raw_list(access_context, exclude: exclude_options)
          expect(dataset.count).to eq(2)
        end
      end
    end

    context '#update' do
      let(:process_opts) { { space: space } }
      let(:process) do
        process_model = AppFactory.make(process_opts)
        ProcessMapper.map_model_to_domain(process_model)
      end

      context 'changing type to an invalid value' do
        it 'raises an InvalidProcess exception' do
          update_opts = { 'type' => 'worker' }

          process_model2 = AppFactory.make(space: space, type: 'worker')

          updated_process = process.with_changes(update_opts)
          neighbor_processes = [ProcessMapper.map_model_to_domain(process_model2)]

          ac = double(:ac, cannot?: false, user: User.make, user_email: 'jim@jim.com')

          update_message = ProcessUpdateMessage.new(process.guid, update_opts)
          allow(process).to receive(:with_changes).with(update_opts).and_return(updated_process)

          expect(process_repo).to receive(:find_for_update).with(process.guid).and_yield(process, space, neighbor_processes)

          expect {
            processes_handler.update(update_message, ac)
          }.to raise_error(ProcessesHandler::InvalidProcess, "Type 'worker' is already in use")
        end
      end

      it 'updates the process and creates an update audit event' do
        update_opts = { 'name' => 'my-process', 'type' => 'web' }

        updated_process = process.with_changes(update_opts)

        ac = double(:ac, cannot?: false, user: User.make, user_email: 'jim@jim.com')

        update_message = ProcessUpdateMessage.new(process.guid, update_opts)

        allow(process).to receive(:with_changes).and_return(updated_process)
        allow(process_repo).to receive(:find_for_update).and_yield(process, space, [])
        allow(process_repo).to receive(:update!).and_return(updated_process)
        allow(process_event_repo).to receive(:record_app_update)

        processes_handler.update(update_message, ac)

        expect(process).to have_received(:with_changes).with(update_opts)
        expect(process_repo).to have_received(:find_for_update).with(process.guid)
        expect(process_repo).to have_received(:update!).with(updated_process)
        expect(process_event_repo).to have_received(:record_app_update).
          with(updated_process, space, ac.user, ac.user_email, update_opts)
      end
    end

    context '#create' do
      it 'saves an event when creating a process' do
        creation_opts = { 'space_guid' => space.guid, 'name' => 'my-process' }

        ac = double(:ac, cannot?: false, user: User.make, user_email: 'jim@jim.com')
        process = AppProcess.new(creation_opts)

        create_message = ProcessCreateMessage.new(creation_opts)

        allow(process_repo).to receive(:new_process).and_return(process)
        allow(process_repo).to receive(:create!).and_return(process)
        allow(process_event_repo).to receive(:record_app_create)

        result = processes_handler.create(create_message, ac)

        expect(process_repo).to have_received(:new_process) do |opts|
          expect(opts).to match(hash_including(create_message.opts))
          expect(opts['guid']).to match(/^[a-z0-9\-]+$/)
        end
        expect(process_repo).to have_received(:create!).with(process)
        expect(process_event_repo).to have_received(:record_app_create).
          with(process, space, ac.user, ac.user_email, creation_opts)

        expect(result).to eq(process)
      end
    end

    describe '#delete' do
      let(:user) { User.make }

      before do
        allow(access_context).to receive(:can?).and_return(true)
        allow(access_context).to receive(:user).and_return(user)
        allow(access_context).to receive(:user_email).and_return('jim@jim.com')
      end

      context 'when the process exists' do
        let(:space) { Space.make }
        let!(:process) do
          process_model = AppFactory.make(space: space)
          ProcessMapper.map_model_to_domain(process_model)
        end
        let(:process_guid) { process.guid }

        it 'saves an event when deleting a process' do
          allow(process_repo).to receive(:find_for_delete).and_yield(process, space)
          allow(process_repo).to receive(:delete).and_return(process)

          expect(process_event_repo).to receive(:record_app_delete_request).
            with(process, space, user, 'jim@jim.com', true)

          expect(processes_handler.delete(access_context, filter: { guid: process.guid })).to eq([process])
        end
      end

      context 'when the process does not exist' do
        it 'returns nil' do
          allow(process_repo).to receive(:find_for_delete).and_yield(nil, nil)
          expect(access_context).to_not receive(:can?)
          expect(processes_handler.delete(access_context, filter: { guid: 'bogus-process' })).to be_empty
        end
      end
    end
  end
end
