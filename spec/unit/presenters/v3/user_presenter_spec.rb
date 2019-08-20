require 'spec_helper'
require 'presenters/v3/user_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe UserPresenter do
    describe '#to_hash' do
      subject do
        UserPresenter.new(user).to_hash
      end

      let(:user) do
        VCAP::CloudController::User.make
      end

      before do
        user.username = 'some-user'
      end

      it 'presents the user as json' do
        expect(subject[:guid]).to eq(user.guid)
        expect(subject[:created_at]).to be_a(Time)
        expect(subject[:updated_at]).to be_a(Time)
        expect(subject[:username]).to eq(user.username)
        expect(subject[:presentation_name]).to eq(user.username)
        expect(subject[:links][:self][:href]).to eq("#{link_prefix}/v3/users/#{user.guid}")
      end

      context 'when the user is a UAA client' do
        before do
          user.username = nil
        end

        it 'presents the client as json' do
          expect(subject[:guid]).to eq(user.guid)
          expect(subject[:created_at]).to be_a(Time)
          expect(subject[:updated_at]).to be_a(Time)
          expect(subject[:username]).to be_nil
          expect(subject[:presentation_name]).to eq(user.guid)
          expect(subject[:links][:self][:href]).to eq("#{link_prefix}/v3/users/#{user.guid}")
        end
      end
    end
  end
end
