require 'spec_helper'
require 'mixins/admin'

module CloudFoundry
  module Middleware
    RSpec.describe 'Admin mixin' do
      let(:implementor) do
        Class.new { include CloudFoundry::Middleware::Admin }.new
      end

      describe '#admin?' do
        before do
          allow(VCAP::CloudController::SecurityContext).to receive_messages(admin?: false, admin_read_only?: false)
        end

        it 'returns true when the user is an admin' do
          allow(VCAP::CloudController::SecurityContext).to receive(:admin?).and_return(true)
          expect(implementor).to be_admin
        end

        it 'returns true when the user is a read-only admin' do
          allow(VCAP::CloudController::SecurityContext).to receive(:admin_read_only?).and_return(true)
          expect(implementor).to be_admin
        end

        it 'returns true when the user is both an admin and a read-only admin' do
          allow(VCAP::CloudController::SecurityContext).to receive_messages(admin?: true, admin_read_only?: true)
          expect(implementor).to be_admin
        end

        it 'returns false when the user is neither an admin nor a read-only admin' do
          expect(implementor).not_to be_admin
        end
      end
    end
  end
end
