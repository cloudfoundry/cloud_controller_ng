require 'securerandom'
require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Permissions::Queryer do
    let(:db_permissions) { instance_double(VCAP::CloudController::Permissions) }
    let(:perm_permissions) { instance_double(VCAP::CloudController::Perm::Permissions) }

    let(:logger) { instance_double(Steno::Logger, info: nil, debug: nil) }
    let(:current_user_guid) { 'some-user-guid' }
    
    let(:space_guid) { 'some-space-guid' }
    let(:org_guid) { 'some-organization-guid' }

    subject(:queryer) do
      Permissions::Queryer.new(
        db_permissions: db_permissions,
        perm_permissions: perm_permissions,
        perm_enabled: true,
        current_user_guid: current_user_guid
      )
    end

    before do
      @experiment = nil

      allow(Steno).to receive(:logger).and_return(logger)
    end

    describe '.build' do
      it 'makes a new queryer object' do
        security_context = class_double(VCAP::CloudController::SecurityContext)
        perm_client = spy(:perm_client)

        roles = instance_double(VCAP::CloudController::Roles)
        allow(security_context).to receive(:roles).and_return(roles)

        issuer = 'some-issuer'

        current_user = spy(:current_user)
        allow(security_context).to receive(:current_user_guid).and_return(current_user_guid)
        allow(security_context).to receive(:current_user).and_return(current_user)
        allow(security_context).to receive(:issuer).and_return(issuer)

        allow(VCAP::CloudController::Permissions).to receive(:new).and_return(db_permissions)
        allow(VCAP::CloudController::Perm::Permissions).to receive(:new).and_return(perm_permissions)
        allow(VCAP::CloudController::Science::Experiment).to receive(:raise_on_mismatches=)

        queryer = Permissions::Queryer.build(perm_client, security_context, true, true)

        expect(VCAP::CloudController::Permissions).to have_received(:new).with(current_user)
        expect(VCAP::CloudController::Perm::Permissions).to have_received(:new).with(
          perm_client: perm_client,
          roles: roles,
          user_id: current_user_guid,
          issuer: issuer
        )
        expect(VCAP::CloudController::Science::Experiment).to have_received(:raise_on_mismatches=).with(true)

        expect(queryer.db_permissions).to eq(db_permissions)
        expect(queryer.perm_permissions).to eq(perm_permissions)
      end
    end

    describe '#can_read_from_space?' do
      before do
        allow(perm_permissions).to receive(:can_read_from_space?)

        allow(db_permissions).to receive(:can_read_from_space?).and_return(true)
        allow(db_permissions).to receive(:can_read_globally?).and_return(false)
      end

      it 'asks for #can_read_from_space? on behalf of the current user' do
        allow(perm_permissions).to receive(:can_read_from_space?).and_return(true)

        queryer.can_read_from_space?(space_guid, org_guid)

        expect(db_permissions).to have_received(:can_read_from_space?).with(space_guid, org_guid)
        expect(perm_permissions).to have_received(:can_read_from_space?).with(space_guid, org_guid)
      end

      it 'skips the experiment if the user is a global reader' do
        allow(db_permissions).to receive(:can_read_globally?).and_return(true)

        queryer.can_read_from_space?(space_guid, org_guid)

        expect(perm_permissions).not_to have_received(:can_read_from_space?)
      end

      it 'uses the expected branch from the experiment' do
        allow(perm_permissions).to receive(:can_read_from_space?).and_return('not-expected')

        response = queryer.can_read_from_space?(space_guid, org_guid)

        expect(response).to eq(true)
      end

      context 'when the control and candidate are the same' do
        it 'logs the result' do
          allow(db_permissions).to receive(:can_read_from_space?).and_return(true)
          allow(perm_permissions).to receive(:can_read_from_space?).and_return(true)

          queryer.can_read_from_space?(space_guid, org_guid)

          expected_context = {
            current_user_guid: current_user_guid,
            space_guid: space_guid,
            org_guid: org_guid,
            action: 'space.read',
          }

          expect(logger).to have_received(:debug).with(
            'matched',
            {
              context: expected_context,
              control: { value: true },
              candidate: { value: true },
            }
          )
        end
      end

      context 'when the control and candidate are different' do
        it 'logs the result' do
          allow(db_permissions).to receive(:can_read_from_space?).and_return(true)
          allow(perm_permissions).to receive(:can_read_from_space?).and_return('something wrong')

          queryer.can_read_from_space?(space_guid, org_guid)

          expected_context = {
            current_user_guid: current_user_guid,
            space_guid: space_guid,
            org_guid: org_guid,
            action: 'space.read',
          }

          expect(logger).to have_received(:info).with(
            'mismatched',
            {
              context: expected_context,
              control: { value: true },
              candidate: { value: 'something wrong' },
            }
          )
        end
      end
    end

    describe '#can_write?' do
      before do
        allow(perm_permissions).to receive(:can_write_to_space?)

        allow(db_permissions).to receive(:can_write_to_space?).and_return(true)
        allow(db_permissions).to receive(:can_write_globally?).and_return(false)
      end

      it 'asks for #can_write_to_space? on behalf of the current user' do
        allow(perm_permissions).to receive(:can_write_to_space?).and_return(true)

        queryer.can_write_to_space?(space_guid)

        expect(db_permissions).to have_received(:can_write_to_space?).with(space_guid)
        expect(perm_permissions).to have_received(:can_write_to_space?).with(space_guid)
      end

      it 'skips the experiment if the user is a global writer' do
        allow(db_permissions).to receive(:can_write_globally?).and_return(true)

        queryer.can_write_to_space?(space_guid)

        expect(perm_permissions).not_to have_received(:can_write_to_space?)
      end

      it 'uses the expected branch from the experiment' do
        allow(perm_permissions).to receive(:can_write_to_space?).and_return('not-expected')

        response = queryer.can_write_to_space?(space_guid)

        expect(response).to eq(true)
      end

      context 'when the control and candidate are the same' do
        it 'logs the result' do
          allow(db_permissions).to receive(:can_write_to_space?).and_return(true)
          allow(perm_permissions).to receive(:can_write_to_space?).and_return(true)

          queryer.can_write_to_space?(space_guid)

          expected_context = {
            current_user_guid: current_user_guid,
            space_guid: space_guid,
            action: 'space.write',
          }

          expect(logger).to have_received(:debug).with(
            'matched',
            {
              context: expected_context,
              control: { value: true },
              candidate: { value: true },
            }
          )
        end
      end

      context 'when the control and candidate are different' do
        it 'logs the result' do
          allow(db_permissions).to receive(:can_write_to_space?).and_return(true)
          allow(perm_permissions).to receive(:can_write_to_space?).and_return('something wrong')

          queryer.can_write_to_space?(space_guid)

          expected_context = {
            current_user_guid: current_user_guid,
            space_guid: space_guid,
            action: 'space.write',
          }

          expect(logger).to have_received(:info).with(
            'mismatched',
            {
              context: expected_context,
              control: { value: true },
              candidate: { value: 'something wrong' },
            }
          )
        end
      end
    end

    describe '#can_write_to_org?' do
      before do
        allow(perm_permissions).to receive(:can_write_to_org?)

        allow(db_permissions).to receive(:can_write_to_org?).and_return(true)
        allow(db_permissions).to receive(:can_write_globally?).and_return(false)
      end

      it 'asks for #can_write_to_org? on behalf of the current user' do
        allow(perm_permissions).to receive(:can_write_to_org?).and_return(true)

        queryer.can_write_to_org?(org_guid)

        expect(db_permissions).to have_received(:can_write_to_org?).with(org_guid)
        expect(perm_permissions).to have_received(:can_write_to_org?).with(org_guid)
      end

      it 'skips the experiment if the user is a global writer' do
        allow(db_permissions).to receive(:can_write_globally?).and_return(true)

        queryer.can_write_to_org?(org_guid)

        expect(perm_permissions).not_to have_received(:can_write_to_org?)
      end

      it 'uses the expected branch from the experiment' do
        allow(perm_permissions).to receive(:can_write_to_org?).and_return('not-expected')

        response = queryer.can_write_to_org?(org_guid)

        expect(response).to eq(true)
      end

      context 'when the control and candidate are the same' do
        it 'logs the result' do
          allow(db_permissions).to receive(:can_write_to_org?).and_return(true)
          allow(perm_permissions).to receive(:can_write_to_org?).and_return(true)

          queryer.can_write_to_org?(org_guid)

          expected_context = {
            current_user_guid: current_user_guid,
            org_guid: org_guid,
            action: 'org.write',
          }

          expect(logger).to have_received(:debug).with(
            'matched',
            {
              context: expected_context,
              control: { value: true },
              candidate: { value: true },
            }
          )
        end
      end

      context 'when the control and candidate are different' do
        it 'logs the result' do
          allow(db_permissions).to receive(:can_write_to_org?).and_return(true)
          allow(perm_permissions).to receive(:can_write_to_org?).and_return('something wrong')

          queryer.can_write_to_org?(org_guid)

          expected_context = {
            current_user_guid: current_user_guid,
            org_guid: org_guid,
            action: 'org.write',
          }

          expect(logger).to have_received(:info).with(
            'mismatched',
            {
              context: expected_context,
              control: { value: true },
              candidate: { value: 'something wrong' },
            }
          )
        end
      end
    end

    describe '#can_read_from_org?' do
      before do
        allow(perm_permissions).to receive(:can_read_from_org?)

        allow(db_permissions).to receive(:can_read_from_org?).and_return(true)
        allow(db_permissions).to receive(:can_read_globally?).and_return(false)
      end

      it 'asks for #can_read_from_org? on behalf of the current user' do
        allow(perm_permissions).to receive(:can_read_from_org?).and_return(true)

        queryer.can_read_from_org?(org_guid)

        expect(db_permissions).to have_received(:can_read_from_org?).with(org_guid)
        expect(perm_permissions).to have_received(:can_read_from_org?).with(org_guid)
      end

      it 'skips the experiment if the user is a global reader' do
        allow(db_permissions).to receive(:can_read_globally?).and_return(true)

        queryer.can_read_from_org?(org_guid)

        expect(perm_permissions).not_to have_received(:can_read_from_org?)
      end

      it 'uses the expected branch from the experiment' do
        allow(perm_permissions).to receive(:can_read_from_org?).and_return('not-expected')

        response = queryer.can_read_from_org?(org_guid)

        expect(response).to eq(true)
      end

      context 'when the control and candidate are the same' do
        it 'logs the result' do
          allow(db_permissions).to receive(:can_read_from_org?).and_return(true)
          allow(perm_permissions).to receive(:can_read_from_org?).and_return(true)

          queryer.can_read_from_org?(org_guid)

          expected_context = {
            current_user_guid: current_user_guid,
            org_guid: org_guid,
            action: 'org.read',
          }

          expect(logger).to have_received(:debug).with(
            'matched',
            {
              context: expected_context,
              control: { value: true },
              candidate: { value: true },
            }
          )
        end
      end

      context 'when the control and candidate are different' do
        it 'logs the result' do
          allow(db_permissions).to receive(:can_read_from_org?).and_return(true)
          allow(perm_permissions).to receive(:can_read_from_org?).and_return('something wrong')

          queryer.can_read_from_org?(org_guid)

          expected_context = {
            current_user_guid: current_user_guid,
            org_guid: org_guid,
            action: 'org.read',
          }

          expect(logger).to have_received(:info).with(
            'mismatched',
            {
              context: expected_context,
              control: { value: true },
              candidate: { value: 'something wrong' },
            }
          )
        end
      end
    end

    describe '#can_write_globally?' do
      before do
        allow(perm_permissions).to receive(:can_write_globally?)

        allow(db_permissions).to receive(:can_write_globally?).and_return(true)
      end

      it 'asks for #can_write_globally? on behalf of the current user' do
        allow(perm_permissions).to receive(:can_write_globally?).and_return(true)

        queryer.can_write_globally?

        expect(db_permissions).to have_received(:can_write_globally?)
      end

      it 'skips the experiment' do
        allow(db_permissions).to receive(:can_read_globally?).and_return(true)

        queryer.can_write_globally?

        expect(perm_permissions).not_to have_received(:can_write_globally?)
      end

      it 'uses the expected branch from the experiment' do
        allow(perm_permissions).to receive(:can_write_globally?).and_return('not-expected')

        response = queryer.can_write_globally?

        expect(response).to eq(true)
      end
    end

    describe '#can_read_globally?' do
      before do
        allow(perm_permissions).to receive(:can_read_globally?)

        allow(db_permissions).to receive(:can_read_globally?).and_return(true)
      end

      it 'asks for #can_read_globally? on behalf of the current user' do
        allow(perm_permissions).to receive(:can_read_globally?).and_return(true)

        queryer.can_read_globally?

        expect(db_permissions).to have_received(:can_read_globally?)
      end

      it 'skips the experiment' do
        allow(db_permissions).to receive(:can_read_globally?).and_return(true)

        queryer.can_read_globally?

        expect(perm_permissions).not_to have_received(:can_read_globally?)
      end

      it 'uses the expected branch from the experiment' do
        allow(perm_permissions).to receive(:can_read_globally?).and_return('not-expected')

        response = queryer.can_read_globally?

        expect(response).to eq(true)
      end
    end

    describe '#can_read_from_isolation_segment?' do
      let(:isolation_segment) { spy(:isolation_segment, guid: 'some-isolation-segment-guid') }

      before do
        allow(perm_permissions).to receive(:can_read_from_isolation_segment?)

        allow(db_permissions).to receive(:can_read_from_isolation_segment?).and_return(true)
        allow(db_permissions).to receive(:can_read_globally?).and_return(false)
      end

      it 'asks for #can_read_from_isolation_segment? on behalf of the current user' do
        allow(perm_permissions).to receive(:can_read_from_isolation_segment?).and_return(true)

        queryer.can_read_from_isolation_segment?(isolation_segment)

        expect(db_permissions).to have_received(:can_read_from_isolation_segment?).with(isolation_segment)
        expect(perm_permissions).to have_received(:can_read_from_isolation_segment?).with(isolation_segment)
      end

      it 'skips the experiment if the user is a global reader' do
        allow(db_permissions).to receive(:can_read_globally?).and_return(true)

        queryer.can_read_from_isolation_segment?(isolation_segment)

        expect(perm_permissions).not_to have_received(:can_read_from_isolation_segment?)
      end

      it 'uses the expected branch from the experiment' do
        allow(perm_permissions).to receive(:can_read_from_isolation_segment?).and_return('not-expected')

        response = queryer.can_read_from_isolation_segment?(isolation_segment)

        expect(response).to eq(true)
      end

      context 'when the control and candidate are the same' do
        it 'logs the result' do
          allow(db_permissions).to receive(:can_read_from_isolation_segment?).and_return(true)
          allow(perm_permissions).to receive(:can_read_from_isolation_segment?).and_return(true)

          queryer.can_read_from_isolation_segment?(isolation_segment)

          expected_context = {
            current_user_guid: current_user_guid,
            isolation_segment_guid: 'some-isolation-segment-guid',
            action: 'isolation_segment.read',
          }

          expect(logger).to have_received(:debug).with(
            'matched',
            {
              context: expected_context,
              control: { value: true },
              candidate: { value: true },
            }
          )
        end
      end

      context 'when the control and candidate are different' do
        it 'logs the result' do
          allow(db_permissions).to receive(:can_read_from_isolation_segment?).and_return(true)
          allow(perm_permissions).to receive(:can_read_from_isolation_segment?).and_return('something wrong')

          queryer.can_read_from_isolation_segment?(isolation_segment)

          expected_context = {
            current_user_guid: current_user_guid,
            isolation_segment_guid: 'some-isolation-segment-guid',
            action: 'isolation_segment.read',
          }

          expect(logger).to have_received(:info).with(
            'mismatched',
            {
              context: expected_context,
              control: { value: true },
              candidate: { value: 'something wrong' },
            }
          )
        end
      end
    end

    describe '#can_read_secrets_in_space?' do
      before do
        allow(perm_permissions).to receive(:can_read_secrets_in_space?)

        allow(db_permissions).to receive(:can_read_secrets_in_space?).and_return(true)
        allow(db_permissions).to receive(:can_read_secrets_globally?).and_return(false)
      end

      it 'asks for #can_read_secrets_in_space? on behalf of the current user' do
        allow(perm_permissions).to receive(:can_read_secrets_in_space?).and_return(true)

        queryer.can_read_secrets_in_space?(space_guid, org_guid)

        expect(db_permissions).to have_received(:can_read_secrets_in_space?).with(space_guid, org_guid)
        expect(perm_permissions).to have_received(:can_read_secrets_in_space?).with(space_guid, org_guid)
      end

      it 'skips the experiment if the user is a global secrets reader' do
        allow(db_permissions).to receive(:can_read_secrets_globally?).and_return(true)

        queryer.can_read_secrets_in_space?(space_guid, org_guid)

        expect(perm_permissions).not_to have_received(:can_read_secrets_in_space?)
      end

      it 'uses the expected branch from the experiment' do
        allow(perm_permissions).to receive(:can_read_secrets_in_space?).and_return('not-expected')

        response = queryer.can_read_secrets_in_space?(space_guid, org_guid)

        expect(response).to eq(true)
      end

      context 'when the control and candidate are the same' do
        it 'logs the result' do
          allow(db_permissions).to receive(:can_read_secrets_in_space?).and_return(true)
          allow(perm_permissions).to receive(:can_read_secrets_in_space?).and_return(true)

          queryer.can_read_secrets_in_space?(space_guid, org_guid)

          expected_context = {
            current_user_guid: current_user_guid,
            space_guid: space_guid,
            org_guid: org_guid,
            action: 'space.read_secrets',
          }

          expect(logger).to have_received(:debug).with(
            'matched',
            {
              context: expected_context,
              control: { value: true },
              candidate: { value: true },
            }
          )
        end
      end

      context 'when the control and candidate are different' do
        it 'logs the result' do
          allow(db_permissions).to receive(:can_read_secrets_in_space?).and_return(true)
          allow(perm_permissions).to receive(:can_read_secrets_in_space?).and_return('something wrong')

          queryer.can_read_secrets_in_space?(space_guid, org_guid)

          expected_context = {
            current_user_guid: current_user_guid,
            space_guid: space_guid,
            org_guid: org_guid,
            action: 'space.read_secrets',
          }

          expect(logger).to have_received(:info).with(
            'mismatched',
            {
              context: expected_context,
              control: { value: true },
              candidate: { value: 'something wrong' },
            }
          )
        end
      end
    end

    describe '#can_read_route?' do
      before do
        allow(perm_permissions).to receive(:can_read_route?)

        allow(db_permissions).to receive(:can_read_route?).and_return(true)
        allow(db_permissions).to receive(:can_read_globally?).and_return(false)
      end

      it 'asks for #can_read_route? on behalf of the current user' do
        allow(perm_permissions).to receive(:can_read_route?).and_return(true)

        queryer.can_read_route?(space_guid, org_guid)

        expect(db_permissions).to have_received(:can_read_route?).with(space_guid, org_guid)
        expect(perm_permissions).to have_received(:can_read_route?).with(space_guid, org_guid)
      end

      it 'skips the experiment if the user is a global reader' do
        allow(db_permissions).to receive(:can_read_globally?).and_return(true)

        queryer.can_read_route?(space_guid, org_guid)

        expect(perm_permissions).not_to have_received(:can_read_route?)
      end

      it 'uses the expected branch from the experiment' do
        allow(perm_permissions).to receive(:can_read_route?).and_return('not-expected')

        response = queryer.can_read_route?(space_guid, org_guid)

        expect(response).to eq(true)
      end

      context 'when the control and candidate are the same' do
        it 'logs the result' do
          allow(db_permissions).to receive(:can_read_route?).and_return(true)
          allow(perm_permissions).to receive(:can_read_route?).and_return(true)

          queryer.can_read_route?(space_guid, org_guid)

          expected_context = {
            current_user_guid: current_user_guid,
            space_guid: space_guid,
            org_guid: org_guid,
            action: 'route.read',
          }

          expect(logger).to have_received(:debug).with(
            'matched',
            {
              context: expected_context,
              control: { value: true },
              candidate: { value: true },
            }
          )
        end
      end

      context 'when the control and candidate are different' do
        it 'logs the result' do
          allow(db_permissions).to receive(:can_read_route?).and_return(true)
          allow(perm_permissions).to receive(:can_read_route?).and_return('something wrong')

          queryer.can_read_route?(space_guid, org_guid)

          expected_context = {
            current_user_guid: current_user_guid,
            space_guid: space_guid,
            org_guid: org_guid,
            action: 'route.read',
          }

          expect(logger).to have_received(:info).with(
            'mismatched',
            {
              context: expected_context,
              control: { value: true },
              candidate: { value: 'something wrong' },
            }
          )
        end
      end
    end

    describe '#readable_space_guids' do
      before do
        allow(db_permissions).to receive(:readable_space_guids)
      end

      it 'delegates the call to the db permission' do
        queryer.readable_space_guids

        expect(db_permissions).to have_received(:readable_space_guids)
      end
    end

    describe '#readable_org_guids' do
      before do
        allow(db_permissions).to receive(:readable_org_guids)
      end

      it 'delegates the call to the db permission' do
        queryer.readable_org_guids

        expect(db_permissions).to have_received(:readable_org_guids)
      end
    end
  end
end
