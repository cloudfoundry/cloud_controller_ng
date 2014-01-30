require "spec_helper"

module VCAP::CloudController
  module Repositories::Runtime
    describe SpaceEventRepository do
      let(:request_attrs) { { "name" => "new-space" } }
      let(:user) { User.make }
      let(:space) { Space.make }

      subject(:space_event_repository) { SpaceEventRepository.new }

      describe "#record_space_create" do
        it "records event correctly" do
          event = space_event_repository.record_space_create(space, user, request_attrs)
          expect(event.space).to eq(space)
          expect(event.type).to eq("audit.space.create")
          expect(event.actee).to eq(space.guid)
          expect(event.actee_type).to eq("space")
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq("user")
          expect(event.metadata).to eq({ "request" => request_attrs})
        end
      end

      describe "#record_space_update" do
        it "records event correctly" do
          event = space_event_repository.record_space_update(space, user, request_attrs)
          expect(event.space).to eq(space)
          expect(event.type).to eq("audit.space.update")
          expect(event.actee).to eq(space.guid)
          expect(event.actee_type).to eq("space")
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq("user")
          expect(event.metadata).to eq({ "request" => request_attrs})
        end
      end

      describe "#record_space_delete" do
        let(:recursive) { true }

        it "records event correctly" do
          event = space_event_repository.record_space_delete_request(space, user, recursive)
          expect(event.space).to be_nil
          expect(event.type).to eq("audit.space.delete-request")
          expect(event.actee).to eq(space.guid)
          expect(event.actee_type).to eq("space")
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq("user")
          expect(event.metadata).to eq({ "request" => { "recursive" => true}})
        end
      end
    end
  end
end
