require 'spec_helper'
require 'presenters/v3/user_presenter'
require 'presenters/helpers/censorship'

module VCAP::CloudController::Presenters::V3
  RSpec.describe UserPresenter do
    describe '#to_hash' do
      let(:user) { VCAP::CloudController::User.make }
      let(:uaa_user_mapping) { { user.guid => { 'origin' => 'some-origin', 'username' => 'some-username' } } }

      let!(:user_label) do
        VCAP::CloudController::UserLabelModel.make(
          resource_guid: user.guid,
          key_prefix: 'maine.gov',
          key_name: 'potato',
          value: 'mashed'
        )
      end

      let!(:user_annotation) do
        VCAP::CloudController::UserAnnotationModel.make(
          resource_guid: user.guid,
          key: 'contacts',
          value: 'Bill tel(1111111) email(bill@fixme), Bob tel(222222) pager(3333333#555) email(bob@fixme)',
        )
      end

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
          expect(subject[:metadata][:labels]).to eq({ 'maine.gov/potato' => 'mashed' })
          expect(subject[:metadata][:annotations]).to eq({ 'contacts' => 'Bill tel(1111111) email(bill@fixme), Bob tel(222222) pager(3333333#555) email(bob@fixme)' })
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
