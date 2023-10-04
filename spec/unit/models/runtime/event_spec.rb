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
        space_guid: space.guid,
        organization_guid: space.organization.guid
      )
    end

    it { is_expected.to have_timestamp_columns }

    context 'when no space is specified' do
      let(:event_attrs) do
        {
          type: 'audit.test',
          actor: 'frank',
          actor_type: 'dude',
          actor_name: 'Frank N Stein',
          actee: 'vlad',
          actee_type: 'vampire',
          actee_name: 'Count Vlad Dracula The Impaler',
          timestamp: Time.new(1999, 9, 9).utc,
          metadata: {}
        }
      end

      it 'fails to create the event' do
        expect { Event.create(event_attrs) }.to raise_error(Event::EventValidationError)
      end

      context 'when an organization is specified' do
        before do
          event_attrs[:organization_guid] = space.organization.guid
        end

        it 'creates an event tied just to the organization' do
          expect { Event.create(event_attrs) }.not_to raise_error

          an_event = Event.first(actor: 'frank')
          expect(an_event.actee).to eq('vlad')
        end
      end
    end

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
      it {
        expect(subject).to export_attributes :type, :actor, :actor_type, :actor_name, :actor_username, :actee, :actee_type, :actee_name,
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

    context 'logging is enabled' do
      let(:fake_logger) { instance_double(Steno::Logger) }

      before do
        TestConfig.config[:log_audit_events] = true
        allow(Steno).to receive(:logger).and_return(fake_logger)
      end

      it 'logs the audit event when the event is created' do
        required_attrs = {
          type: 'audit.test',
          timestamp: Time.new(1999, 9, 9).utc,
          actor: 'shatner',
          actor_type: 'pork',
          actor_username: 'chop',
          actee: 'nimoy',
          actee_type: 'vulcan',
          actee_name: 'Mr. Spock',
          space: space

        }
        event = Event.new(required_attrs)
        allow(fake_logger).to receive(:info)

        event.save

        expect(fake_logger).to have_received(:info).with(/audit.test/)
        expect(fake_logger).to have_received(:info).with(/#{event.guid}/)
      end
    end

    describe 'supports deleted spaces (for auditing purposes)' do
      context 'when the space is deleted' do
        let(:space_guid) { 'space-guid-1234' }

        let(:new_org) { Organization.make }
        let(:new_space) { Space.make(guid: space_guid, organization: new_org) }
        let!(:new_event) { Event.make(space_guid: new_space.guid, organization_guid: new_org.guid) }

        before { new_space.destroy }

        it 'the event continues to exist' do
          expect(Space.find(id: new_space.id)).to be_nil
          expect(Event.find(id: new_event.id)).not_to be_nil
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
