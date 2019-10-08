require 'spec_helper'
require 'presenters/v3/role_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe RolePresenter do
    subject(:presenter) { RolePresenter.new(role) }

    let(:role) { VCAP::CloudController::SpaceAuditor.make }

    describe '#to_hash' do
      let(:result) { presenter.to_hash }

      it 'presents the role' do
        expect(result[:guid]).to eq(role.guid)
        expect(result[:created_at]).to eq(role.created_at)
        expect(result[:updated_at]).to eq(role.updated_at)
        expect(result[:type]).to eq('space_auditor')
        expect(result[:relationships][:user][:data][:guid]).to eq(role.user.guid)
        expect(result[:relationships][:space][:data][:guid]).to eq(role.space.guid)
        expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/roles/#{role.guid}")
        expect(result[:links][:user][:href]).to eq("#{link_prefix}/v3/users/#{role.user.guid}")
        expect(result[:links][:space][:href]).to eq("#{link_prefix}/v3/spaces/#{role.space.guid}")
      end
    end
  end
end
