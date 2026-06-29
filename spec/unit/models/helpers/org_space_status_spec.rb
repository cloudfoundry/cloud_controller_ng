require 'spec_helper'
require 'models/helpers/org_space_status'

module VCAP::CloudController
  RSpec.describe OrgSpaceStatus do
    let(:host_class) do
      Class.new do
        include OrgSpaceStatus

        attr_accessor :status
      end
    end
    let(:resource) { host_class.new }

    describe 'constants' do
      it 'exposes status string constants' do
        expect(OrgSpaceStatus::ACTIVE).to eq('active')
        expect(OrgSpaceStatus::SUSPENDED).to eq('suspended')
        expect(OrgSpaceStatus::DELETING).to eq('deleting')
      end

      it 'lists VALID_STATUSES' do
        expect(OrgSpaceStatus::VALID_STATUSES).to eq(%w[active suspended deleting])
      end

      it 'freezes the constants' do
        expect(OrgSpaceStatus::ACTIVE).to be_frozen
        expect(OrgSpaceStatus::SUSPENDED).to be_frozen
        expect(OrgSpaceStatus::DELETING).to be_frozen
        expect(OrgSpaceStatus::VALID_STATUSES).to be_frozen
      end
    end

    describe '#active?' do
      it 'is true only when status is active' do
        resource.status = 'active'
        expect(resource.active?).to be true

        resource.status = 'suspended'
        expect(resource.active?).to be false

        resource.status = 'deleting'
        expect(resource.active?).to be false
      end
    end

    describe '#suspended?' do
      it 'is true only when status is suspended' do
        resource.status = 'suspended'
        expect(resource.suspended?).to be true

        resource.status = 'active'
        expect(resource.suspended?).to be false

        resource.status = 'deleting'
        expect(resource.suspended?).to be false
      end
    end

    describe '#deleting?' do
      it 'is true only when status is deleting' do
        resource.status = 'deleting'
        expect(resource.deleting?).to be true

        resource.status = 'active'
        expect(resource.deleting?).to be false

        resource.status = 'suspended'
        expect(resource.deleting?).to be false
      end
    end
  end
end
