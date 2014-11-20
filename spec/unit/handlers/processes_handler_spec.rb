require 'spec_helper'
require 'handlers/processes_handler'

module VCAP::CloudController
  describe ProcessesHandler do
    let(:security_context) { double(:sc, current_user: User.new(guid: "123"), current_user_email: "user@user.com") }

    context '#update' do
      it 'updates the process and creates an update audit event' do
        update_opts = { name: "my-process" }

        space = Space.make
        process_model = AppFactory.make(space: space)
        process = ProcessMapper.map_model_to_domain(process_model)
        updated_process = process.with_changes(update_opts)

        ac = double(:ac, cannot?: false, user: User.make, user_email: "jim@jim.com")
        process_repo = double(:process_repo)
        process_event_repo = double(:process_event_repo)

        handler = ProcessesHandler.new(process_repo, process_event_repo)
        update_message = ProcessUpdateMessage.new(process.guid, update_opts)
        allow(process).to receive(:with_changes).with(update_opts).and_return(updated_process)

        expect(process_repo).to receive(:find_for_update).with(process.guid).and_yield(process, space)
        expect(process_repo).to receive(:persist!).with(updated_process).and_return(updated_process)
        expect(process_event_repo).to receive(:record_app_update)
          .with(updated_process, space, ac.user, ac.user_email, update_opts)

        handler.update(update_message, ac)
      end
    end

    context "#create" do
      it "saves an event when creating a process" do
        space = Space.make

        creation_opts = { space_guid: space.guid, name: "my-process" }

        ac = double(:ac, cannot?: false, user: User.make, user_email: "jim@jim.com")
        process_repo = double(:process_repo)
        process_event_repo = double(:process_event_repo)
        process = AppProcess.new(creation_opts)

        handler = ProcessesHandler.new(process_repo, process_event_repo)
        create_message = ProcessCreateMessage.new(creation_opts)

        expect(process_repo).to receive(:new_process).with(create_message.opts).and_return(process)
        expect(process_repo).to receive(:persist!).with(process).and_return(process)
        expect(process_event_repo).to receive(:record_app_create)
          .with(process, space, ac.user, ac.user_email, creation_opts)

        expect(handler.create(create_message, ac)).to eq(process)
      end
    end

    context '#delete' do
      it 'saves an event when deleting a process' do
        ac = double(:ac, user: User.make, user_email: "jim@jim.com")
        process_repo = double(:process_repo)
        process_event_repo = double(:process_event_repo)

        space = Space.make
        process_model = AppFactory.make(space: space)
        process = ProcessMapper.map_model_to_domain(process_model)

        expect(ac).to receive(:cannot?).with(:delete, process, space).and_return(false)
        allow(process_repo).to receive(:find_for_update).and_yield(process, space)
        allow(process_repo).to receive(:delete).and_return(process)
        expect(process_event_repo).to receive(:record_app_delete_request)
          .with(process, space, ac.user, ac.user_email, true)

        handler = ProcessesHandler.new(process_repo, process_event_repo)
        expect(handler.delete(process.guid, ac)).to eq(process)
      end
    end
  end
end
