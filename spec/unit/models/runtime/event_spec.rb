require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Event, type: :model do
    let(:space) { Space.make }

    let(:event) do
      Event.make(
        type: 'audit.movie.premiere',
        actor: 'ncage',
        actor_type: 'One True God',
        actor_name: 'Nicolas Cage',
        actee: 'jtravolta',
        actee_type: 'Scientologist',
        actee_name: 'John Travolta',
        timestamp: Time.new(1997, 6, 27).utc,
        metadata: { 'popcorn_price' => '$(arm + leg)' },
        space: space
      )
    end

    it { is_expected.to have_timestamp_columns }

    describe 'Associations' do
      it { is_expected.to have_associated :space }
    end

    describe 'Validations' do
      it { is_expected.to validate_presence :type }
      it { is_expected.to validate_presence :timestamp }
      it { is_expected.to validate_presence :actor }
      it { is_expected.to validate_presence :actor_type }
      it { is_expected.to validate_presence :actee }
      it { is_expected.to validate_presence :actee_type }
      it { is_expected.to validate_not_null :actee_name }
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :type, :actor, :actor_type, :actor_name, :actee, :actee_type, :actee_name,
                                    :timestamp, :metadata, :space_guid, :organization_guid
      }
      it { is_expected.to import_attributes }
    end

    it 'has a data bag' do
      expect(event.metadata).to eq({ 'popcorn_price' => '$(arm + leg)' })
    end

    it 'has a space' do
      expect(event.space.guid).to eq(space.guid)
    end

    it 'has a space guid' do
      expect(event.space_guid).to eq(space.guid)
    end

    it 'has an organization guid' do
      expect(event.organization_guid).to eq(space.organization.guid)
    end

    describe 'supports deleted spaces (for auditing purposes)' do
      context 'when the space is deleted' do
        let(:space_guid) { 'space-guid-1234' }

        let(:new_org) { Organization.make }
        let(:new_space) { Space.make(guid: space_guid, organization: new_org) }
        let!(:new_event) { Event.make(space: new_space) }

        before { new_space.destroy }

        it 'the event continues to exist' do
          expect(Space.find(id: new_space.id)).to be_nil
          expect(Event.find(id: new_event.id)).to_not be_nil
        end

        it 'returns nil' do
          expect(new_event.space).to be_nil
        end

        it 'has a denormalized space guid' do
          expect(new_event.space_guid).to eq(space_guid)
        end

        it 'has an denormalized organization guid' do
          expect(new_event.organization_guid).to eq(new_org.guid)
        end
      end
    end
  end
end
