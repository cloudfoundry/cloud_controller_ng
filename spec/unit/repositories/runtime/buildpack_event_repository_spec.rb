require 'spec_helper'

module VCAP::CloudController
  module Repositories::Runtime
    describe BuildpackEventRepository do
      let(:user) { User.make }
      let(:buildpack) { Buildpack.make }
      let(:user_email) { 'email address' }

      subject(:buildpack_event_repository) { BuildpackEventRepository.new }

      describe '#record_buildpack_delete' do
        it 'records event correctly' do
          event = buildpack_event_repository.record_buildpack_delete_request(buildpack, user, user_email)
          event.reload
          expect(event.type).to eq('audit.buildpack.delete-request')
          expect(event.actee).to eq(buildpack.guid)
          expect(event.actee_type).to eq('buildpack')
          expect(event.actee_name).to eq(buildpack.name)
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
        end
      end
    end
  end
end
