require 'spec_helper'
require 'presenters/v3/user_presenter'
require 'presenters/helpers/censorship'

module VCAP::CloudController::Presenters::V3
  RSpec.describe UserPresenter do
    describe '#to_hash' do
      let(:user) { VCAP::CloudController::User.make }
      let(:uaa_user_mapping) { { user.guid => { 'origin' => 'some-origin', 'username' => 'some-username' } } }

      context 'when the user is a UAA user' do
        subject do
          UserPresenter.new(user, uaa_users: uaa_user_mapping).to_hash
        end
        it 'presents the user as json' do
          expect(subject[:guid]).to eq(user.guid)
          expect(subject[:created_at]).to be_a(Time)
          expect(subject[:updated_at]).to be_a(Time)
          expect(subject[:username]).to eq('some-username')
          expect(subject[:presentation_name]).to eq('some-username')
          expect(subject[:origin]).to eq('some-origin')
          expect(subject[:links][:self][:href]).to eq("#{link_prefix}/v3/users/#{user.guid}")
        end
      end

      context 'when the user is a UAA client' do
        subject do
          UserPresenter.new(user, uaa_users: {}).to_hash
        end

        it 'presents the client as json' do
          expect(subject[:guid]).to eq(user.guid)
          expect(subject[:created_at]).to be_a(Time)
          expect(subject[:updated_at]).to be_a(Time)
          expect(subject[:username]).to be_nil
          expect(subject[:presentation_name]).to eq(user.guid)
          expect(subject[:origin]).to be_nil
          expect(subject[:links][:self][:href]).to eq("#{link_prefix}/v3/users/#{user.guid}")
        end
      end
    end
  end
end
