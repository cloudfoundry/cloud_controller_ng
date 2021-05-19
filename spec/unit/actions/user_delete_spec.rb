require 'spec_helper'
require 'actions/user_delete'

module VCAP::CloudController
  RSpec.describe UserDeleteAction do
    subject(:user_delete) { UserDeleteAction.new }

    describe '#delete' do
      let!(:user) { User.make }

      it 'deletes the user record' do
        expect {
          user_delete.delete([user])
        }.to change { User.count }.by(-1)
        expect { user.refresh }.to raise_error Sequel::Error, 'Record not found'
      end
    end
  end
end
