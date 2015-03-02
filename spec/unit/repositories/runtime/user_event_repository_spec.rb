require 'spec_helper'

module VCAP::CloudController
  module Repositories::Runtime
    describe UserEventRepository do
      let(:actor) { User.make }
      let(:user) { User.make }
      let(:actor_email) { 'email address' }

      subject(:user_event_repository) { UserEventRepository.new }

      describe '#record_user_delete' do
        it 'records event correctly' do
          event = user_event_repository.record_user_delete_request(user, actor, actor_email)
          event.reload
          expect(event.space).to be_nil
          expect(event.type).to eq('audit.user.delete-request')
          expect(event.actee).to eq(user.guid)
          expect(event.actee_type).to eq('user')
          expect(event.actee_name).to eq(user.guid)
          expect(event.actor).to eq(actor.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(actor_email)
        end
      end
    end
  end
end
