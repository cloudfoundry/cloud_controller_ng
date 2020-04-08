require 'securerandom'
require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Permissions::Queryer do
    let(:db_permissions) { instance_double(VCAP::CloudController::Permissions) }
    let(:perm_permissions) { instance_double(VCAP::CloudController::Perm::Permissions) }

    let(:statsd_client) { spy(Statsd, gauge: nil) }
    let(:logger) { instance_double(Steno::Logger, info: nil, debug: nil) }
    let(:current_user_guid) { 'some-user-guid' }

    let(:space_guid) { 'some-space-guid' }
    let(:org_guid) { 'some-organization-guid' }

    subject do
      Permissions::Queryer.new(
        db_permissions: db_permissions,
        perm_permissions: perm_permissions,
        statsd_client: statsd_client,
        perm_enabled: true,
        current_user_guid: current_user_guid
      )
    end

    before do
      @experiment = nil

      allow(Steno).to receive(:logger).and_return(logger)
    end

    RSpec.shared_examples 'match recorder' do |query_fn, method, control_value, candidate_value, additional_context={}|
      experiment_name = method.to_s.delete('?')

      it 'logs the match' do
        query_fn.call(subject)

        expected_context = {
          current_user_guid: current_user_guid,
        }.merge(additional_context)

        expect(Steno).to have_received(:logger).with("science.#{experiment_name}")

        expect(logger).to have_received(:debug).with(
          'matched',
          {
            context: expected_context,
            control: { value: control_value },
            candidate: { value: candidate_value },
          }
        )
      end

      it 'publishes the success to statsd' do
        query_fn.call(subject)

        expect(statsd_client).to have_received(:gauge).with("cc.perm.experiment.#{experiment_name}.match", 1)
        expect(statsd_client).to have_received(:gauge).with('cc.perm.experiment.match', 1)
      end

      it 'publishes the performance of both control and candidate' do
        Timecop.freeze do
          control_duration = 10
          candidate_duration = 5

          allow(db_permissions).to receive(method.to_sym) do
            Timecop.travel(control_duration)
            true
          end

          allow(perm_permissions).to receive(method.to_sym) do
            Timecop.travel(candidate_duration)
            true
          end

          query_fn.call(subject)

          expect(statsd_client).to have_received(:timing).
            with("cc.perm.experiment.#{experiment_name}.timing.match.control", be_within(100).of(control_duration * 1000))
          expect(statsd_client).to have_received(:timing).
            with("cc.perm.experiment.#{experiment_name}.timing.match.candidate", be_within(100).of(candidate_duration * 1000))
        end
      end
    end

    RSpec.shared_examples 'mismatch recorder' do |query_fn, method, control_value, candidate_value, additional_context={}|
      experiment_name = method.to_s.delete('?')

      it 'logs the mismatch' do
        query_fn.call(subject)

        expected_context = {
          current_user_guid: current_user_guid,
        }.merge(additional_context)

        expect(Steno).to have_received(:logger).with("science.#{experiment_name}")

        expect(logger).to have_received(:info).with(
          'mismatched',
          {
            context: expected_context,
            control: { value: control_value },
            candidate: { value: candidate_value },
          }
        )
      end

      it 'publishes the failure to statsd' do
        query_fn.call(subject)

        expect(statsd_client).to have_received(:gauge).with("cc.perm.experiment.#{experiment_name}.match", 0)
        expect(statsd_client).to have_received(:gauge).with('cc.perm.experiment.match', 0)
      end

      it 'publishes the performance of both control and candidate' do
        Timecop.freeze do
          control_duration = 10
          candidate_duration = 5

          allow(db_permissions).to receive(method.to_sym) do
            Timecop.travel(control_duration)
            :a
          end

          allow(perm_permissions).to receive(method.to_sym) do
            Timecop.travel(candidate_duration)
            :b
          end

          query_fn.call(subject)

          expect(statsd_client).to have_received(:timing).
            with("cc.perm.experiment.#{experiment_name}.timing.mismatch.control", be_within(100).of(control_duration * 1000))
          expect(statsd_client).to have_received(:timing).
            with("cc.perm.experiment.#{experiment_name}.timing.mismatch.candidate", be_within(100).of(candidate_duration * 1000))
        end
      end
    end

    RSpec.shared_examples 'readable guids' do |name|
      method = "readable_#{name}_guids"
      method_sym = method.to_sym

      before do
        allow(perm_permissions).to receive(method_sym)
        allow(db_permissions).to receive(method_sym)

        allow(db_permissions).to receive(:can_read_globally?).and_return(false)
      end

      it "asks for #{method} on behalf of the current user" do
        subject.send(method_sym)

        expect(db_permissions).to have_received(method_sym)
        expect(perm_permissions).to have_received(method_sym)
      end

      it 'returns the control guids' do
        control_guids = [SecureRandom.uuid]
        candidate_guids = [SecureRandom.uuid]

        allow(db_permissions).to receive(method_sym).and_return(control_guids)
        allow(perm_permissions).to receive(method_sym).and_return(candidate_guids)

        readable_guids = subject.send(method_sym)

        expect(readable_guids).to equal(control_guids)
      end

      it 'skips the experiment if the user is a global reader' do
        allow(db_permissions).to receive(:can_read_globally?).and_return(true)

        subject.send(method_sym)

        expect(perm_permissions).not_to have_received(method_sym)
      end

      context 'when the control and candidate are the same' do
        guids = [SecureRandom.uuid, SecureRandom.uuid]

        before do
          allow(db_permissions).to receive(method_sym).and_return(guids)
          allow(perm_permissions).to receive(method_sym).and_return(guids)
        end

        it_behaves_like 'match recorder', proc { |queryer| queryer.send(method_sym) }, method, guids, guids
      end

      context 'when the control and candidate are the same but in a different order' do
        guid1 = SecureRandom.uuid
        guid2 = SecureRandom.uuid

        control_order_guids = [guid1, guid2]
        candidate_order_guids = [guid2, guid1]

        before do
          allow(db_permissions).to receive(method_sym).and_return(control_order_guids)
          allow(perm_permissions).to receive(method_sym).and_return(candidate_order_guids)
        end

        it_behaves_like 'match recorder', proc { |queryer| queryer.send(method_sym) }, method, control_order_guids, candidate_order_guids
      end

      context 'when the control and candidate are different' do
        control_guids = [SecureRandom.uuid, SecureRandom.uuid]
        candidate_guids = [SecureRandom.uuid]

        before do
          allow(db_permissions).to receive(method_sym).and_return(control_guids)
          allow(perm_permissions).to receive(method_sym).and_return(candidate_guids)
        end

        it_behaves_like 'mismatch recorder', proc { |queryer| queryer.send(method_sym) }, method, control_guids, candidate_guids
      end
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

        expected_queryer = double(:queryer)

        allow(Permissions::Queryer).to receive(:new).
          with(
            db_permissions: db_permissions,
            perm_permissions: perm_permissions,
            statsd_client: statsd_client,
            perm_enabled: true,
            current_user_guid: current_user_guid,
          ).
          and_return(expected_queryer)

        actual_queryer = Permissions::Queryer.build(perm_client, statsd_client, security_context, true, true)

        expect(actual_queryer).to eq(expected_queryer)

        expect(VCAP::CloudController::Permissions).to have_received(:new).with(current_user)
        expect(VCAP::CloudController::Perm::Permissions).to have_received(:new).with(
          perm_client: perm_client,
          roles: roles,
          user_id: current_user_guid,
          issuer: issuer
        )
      end
    end

    describe '#can_read_globally?' do
      before do
        allow(perm_permissions).to receive(:can_read_globally?)

        allow(db_permissions).to receive(:can_read_globally?).and_return(true)
      end

      it 'asks for #can_read_globally? on behalf of the current user' do
        allow(perm_permissions).to receive(:can_read_globally?).and_return(true)

        subject.can_read_globally?

        expect(db_permissions).to have_received(:can_read_globally?)
      end

      it 'skips the experiment' do
        allow(db_permissions).to receive(:can_read_globally?).and_return(true)

        subject.can_read_globally?

        expect(perm_permissions).not_to have_received(:can_read_globally?)
      end

      it 'uses the expected branch from the experiment' do
        allow(perm_permissions).to receive(:can_read_globally?).and_return('not-expected')

        response = subject.can_read_globally?

        expect(response).to eq(true)
      end
    end

    describe '#can_write_globally?' do
      before do
        allow(perm_permissions).to receive(:can_write_globally?)

        allow(db_permissions).to receive(:can_write_globally?).and_return(true)
      end

      it 'asks for #can_write_globally? on behalf of the current user' do
        allow(perm_permissions).to receive(:can_write_globally?).and_return(true)

        subject.can_write_globally?

        expect(db_permissions).to have_received(:can_write_globally?)
      end

      it 'skips the experiment' do
        allow(db_permissions).to receive(:can_read_globally?).and_return(true)

        subject.can_write_globally?

        expect(perm_permissions).not_to have_received(:can_write_globally?)
      end

      it 'uses the expected branch from the experiment' do
        allow(perm_permissions).to receive(:can_write_globally?).and_return('not-expected')

        response = subject.can_write_globally?

        expect(response).to eq(true)
      end
    end

    describe '#can_read_secrets_globally?' do
      before do
        allow(perm_permissions).to receive(:can_read_secrets_globally?)

        allow(db_permissions).to receive(:can_read_secrets_globally?).and_return(true)
      end

      it 'asks for #can_read_secrets_globally? on behalf of the current user' do
        allow(perm_permissions).to receive(:can_read_secrets_globally?).and_return(true)

        subject.can_read_secrets_globally?

        expect(db_permissions).to have_received(:can_read_secrets_globally?)
      end

      it 'skips the experiment' do
        allow(db_permissions).to receive(:can_read_secrets_globally?).and_return(true)

        subject.can_read_secrets_globally?

        expect(perm_permissions).not_to have_received(:can_read_secrets_globally?)
      end

      it 'uses the expected branch from the experiment' do
        allow(perm_permissions).to receive(:can_read_secrets_globally?).and_return('not-expected')

        response = subject.can_read_secrets_globally?

        expect(response).to eq(true)
      end
    end

    describe '#readable_org_guids' do
      it_behaves_like 'readable guids', 'org'
    end

    describe '#readable_org_contents_org_guids' do
      it_behaves_like 'readable guids', 'org_contents_org'
    end

    describe '#can_read_from_org?' do
      before do
        allow(perm_permissions).to receive(:can_read_from_org?)

        allow(db_permissions).to receive(:can_read_from_org?).and_return(true)
        allow(db_permissions).to receive(:can_read_globally?).and_return(false)
      end

      it 'asks for #can_read_from_org? on behalf of the current user' do
        allow(perm_permissions).to receive(:can_read_from_org?).and_return(true)

        subject.can_read_from_org?(org_guid)

        expect(db_permissions).to have_received(:can_read_from_org?).with(org_guid)
        expect(perm_permissions).to have_received(:can_read_from_org?).with(org_guid)
      end

      it 'skips the experiment if the user is a global reader' do
        allow(db_permissions).to receive(:can_read_globally?).and_return(true)

        subject.can_read_from_org?(org_guid)

        expect(perm_permissions).not_to have_received(:can_read_from_org?)
      end

      it 'uses the expected branch from the experiment' do
        allow(perm_permissions).to receive(:can_read_from_org?).and_return('not-expected')

        response = subject.can_read_from_org?(org_guid)

        expect(response).to eq(true)
      end

      context 'when the control and candidate are the same' do
        org_guid = "read-from-org-#{SecureRandom.uuid}"

        before do
          allow(db_permissions).to receive(:can_read_from_org?).and_return(true)
          allow(perm_permissions).to receive(:can_read_from_org?).and_return(true)
        end

        it_behaves_like 'match recorder', proc { |queryer| queryer.can_read_from_org?(org_guid) }, :can_read_from_org?, true, true, { org_guid: org_guid }
      end

      context 'when the control and candidate are different' do
        org_guid = "can-read-from-org-#{SecureRandom.uuid}"

        before do
          allow(db_permissions).to receive(:can_read_from_org?).and_return(true)
          allow(perm_permissions).to receive(:can_read_from_org?).and_return('something wrong')
        end

        it_behaves_like 'mismatch recorder', proc { |queryer| queryer.can_read_from_org?(org_guid) }, :can_read_from_org?, true, 'something wrong', { org_guid: org_guid }
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

        subject.can_write_to_org?(org_guid)

        expect(db_permissions).to have_received(:can_write_to_org?).with(org_guid)
        expect(perm_permissions).to have_received(:can_write_to_org?).with(org_guid)
      end

      it 'skips the experiment if the user is a global writer' do
        allow(db_permissions).to receive(:can_write_globally?).and_return(true)

        subject.can_write_to_org?(org_guid)

        expect(perm_permissions).not_to have_received(:can_write_to_org?)
      end

      it 'uses the expected branch from the experiment' do
        allow(perm_permissions).to receive(:can_write_to_org?).and_return('not-expected')

        response = subject.can_write_to_org?(org_guid)

        expect(response).to eq(true)
      end

      context 'when the control and candidate are the same' do
        it 'logs the result' do
          allow(db_permissions).to receive(:can_write_to_org?).and_return(true)
          allow(perm_permissions).to receive(:can_write_to_org?).and_return(true)

          subject.can_write_to_org?(org_guid)

          expected_context = {
            current_user_guid: current_user_guid,
            org_guid: org_guid,
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
        org_guid = SecureRandom.uuid

        before do
          allow(db_permissions).to receive(:can_write_to_org?).and_return(true)
          allow(perm_permissions).to receive(:can_write_to_org?).and_return('something wrong')
        end

        it_behaves_like 'mismatch recorder', proc { |queryer| queryer.can_write_to_org?(org_guid) }, :can_write_to_org?, true, 'something wrong', { org_guid: org_guid }
      end
    end

    describe '#readable_space_guids' do
      it_behaves_like 'readable guids', 'space'
    end

    describe '#can_read_from_space?' do
      before do
        allow(perm_permissions).to receive(:can_read_from_space?)

        allow(db_permissions).to receive(:can_read_from_space?).and_return(true)
        allow(db_permissions).to receive(:can_read_globally?).and_return(false)
      end

      it 'asks for #can_read_from_space? on behalf of the current user' do
        allow(perm_permissions).to receive(:can_read_from_space?).and_return(true)

        subject.can_read_from_space?(space_guid, org_guid)

        expect(db_permissions).to have_received(:can_read_from_space?).with(space_guid, org_guid)
        expect(perm_permissions).to have_received(:can_read_from_space?).with(space_guid, org_guid)
      end

      it 'skips the experiment if the user is a global reader' do
        allow(db_permissions).to receive(:can_read_globally?).and_return(true)

        subject.can_read_from_space?(space_guid, org_guid)

        expect(perm_permissions).not_to have_received(:can_read_from_space?)
      end

      it 'uses the expected branch from the experiment' do
        allow(perm_permissions).to receive(:can_read_from_space?).and_return('not-expected')

        response = subject.can_read_from_space?(space_guid, org_guid)

        expect(response).to eq(true)
      end

      context 'when the control and candidate are the same' do
        org_guid = SecureRandom.uuid
        space_guid = SecureRandom.uuid

        before do
          allow(db_permissions).to receive(:can_read_from_space?).and_return(true)
          allow(perm_permissions).to receive(:can_read_from_space?).and_return(true)
        end

        it_behaves_like(
          'match recorder',
          proc { |queryer| queryer.can_read_from_space?(space_guid, org_guid) },
          :can_read_from_space?,
          true,
          true,
          { space_guid: space_guid, org_guid: org_guid },
        )
      end

      context 'when the control and candidate are different' do
        org_guid = SecureRandom.uuid
        space_guid = SecureRandom.uuid

        before do
          allow(db_permissions).to receive(:can_read_from_space?).and_return(true)
          allow(perm_permissions).to receive(:can_read_from_space?).and_return('something wrong')
        end

        it_behaves_like(
          'mismatch recorder',
          proc { |queryer| queryer.can_read_from_space?(space_guid, org_guid) },
          :can_read_from_space?,
          true,
          'something wrong',
          { space_guid: space_guid, org_guid: org_guid },
        )
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

        subject.can_read_secrets_in_space?(space_guid, org_guid)

        expect(db_permissions).to have_received(:can_read_secrets_in_space?).with(space_guid, org_guid)
        expect(perm_permissions).to have_received(:can_read_secrets_in_space?).with(space_guid, org_guid)
      end

      it 'skips the experiment if the user is a global secrets reader' do
        allow(db_permissions).to receive(:can_read_secrets_globally?).and_return(true)

        subject.can_read_secrets_in_space?(space_guid, org_guid)

        expect(perm_permissions).not_to have_received(:can_read_secrets_in_space?)
      end

      it 'uses the expected branch from the experiment' do
        allow(perm_permissions).to receive(:can_read_secrets_in_space?).and_return('not-expected')

        response = subject.can_read_secrets_in_space?(space_guid, org_guid)

        expect(response).to eq(true)
      end

      context 'when the control and candidate are the same' do
        space_guid = SecureRandom.uuid
        org_guid = SecureRandom.uuid

        before do
          allow(db_permissions).to receive(:can_read_secrets_in_space?).and_return(true)
          allow(perm_permissions).to receive(:can_read_secrets_in_space?).and_return(true)
        end

        it_behaves_like('match recorder',
          proc { |queryer| queryer.can_read_secrets_in_space?(space_guid, org_guid) },
          :can_read_secrets_in_space?,
          true,
          true,
          {
            space_guid: space_guid,
            org_guid: org_guid, }
        )
      end

      context 'when the control and candidate are different' do
        space_guid = SecureRandom.uuid
        org_guid = SecureRandom.uuid

        before do
          allow(db_permissions).to receive(:can_read_secrets_in_space?).and_return(true)
          allow(perm_permissions).to receive(:can_read_secrets_in_space?).and_return('something wrong')
        end

        it_behaves_like('mismatch recorder',
          proc { |queryer| queryer.can_read_secrets_in_space?(space_guid, org_guid) },
          :can_read_secrets_in_space?,
          true,
          'something wrong',
          {
            space_guid: space_guid,
            org_guid: org_guid, }
        )
      end
    end

    describe '#can_write_to_space?' do
      before do
        allow(perm_permissions).to receive(:can_write_to_space?)

        allow(db_permissions).to receive(:can_write_to_space?).and_return(true)
        allow(db_permissions).to receive(:can_write_globally?).and_return(false)
      end

      it 'asks for #can_write_to_space? on behalf of the current user' do
        allow(perm_permissions).to receive(:can_write_to_space?).and_return(true)

        subject.can_write_to_space?(space_guid)

        expect(db_permissions).to have_received(:can_write_to_space?).with(space_guid)
        expect(perm_permissions).to have_received(:can_write_to_space?).with(space_guid)
      end

      it 'skips the experiment if the user is a global writer' do
        allow(db_permissions).to receive(:can_write_globally?).and_return(true)

        subject.can_write_to_space?(space_guid)

        expect(perm_permissions).not_to have_received(:can_write_to_space?)
      end

      it 'uses the expected branch from the experiment' do
        allow(perm_permissions).to receive(:can_write_to_space?).and_return('not-expected')

        response = subject.can_write_to_space?(space_guid)

        expect(response).to eq(true)
      end

      context 'when the control and candidate are the same' do
        space_guid = SecureRandom.uuid

        before do
          allow(db_permissions).to receive(:can_write_to_space?).and_return(true)
          allow(perm_permissions).to receive(:can_write_to_space?).and_return(true)
        end

        it_behaves_like('match recorder',
          proc { |queryer| queryer.can_write_to_space?(space_guid) },
          :can_write_to_space?,
          true,
          true,
          space_guid: space_guid
        )
      end

      context 'when the control and candidate are different' do
        space_guid = SecureRandom.uuid

        before do
          allow(db_permissions).to receive(:can_write_to_space?).and_return(true)
          allow(perm_permissions).to receive(:can_write_to_space?).and_return('something wrong')
        end

        it_behaves_like('mismatch recorder',
          proc { |queryer| queryer.can_write_to_space?(space_guid) },
          :can_write_to_space?,
          true,
          'something wrong',
          space_guid: space_guid
        )
      end
    end

    describe '#can_update_space?' do
      before do
        allow(perm_permissions).to receive(:can_update_space?)

        allow(db_permissions).to receive(:can_update_space?).and_return(true)
        allow(db_permissions).to receive(:can_write_globally?).and_return(false)
      end

      it 'asks for #can_update_space? on behalf of the current user' do
        allow(perm_permissions).to receive(:can_update_space?).and_return(true)

        subject.can_update_space?(space_guid, org_guid)

        expect(db_permissions).to have_received(:can_update_space?).with(space_guid, org_guid)
        expect(perm_permissions).to have_received(:can_update_space?).with(space_guid, org_guid)
      end

      it 'skips the experiment if the user is a global writer' do
        allow(db_permissions).to receive(:can_write_globally?).and_return(true)

        subject.can_update_space?(space_guid, org_guid)

        expect(perm_permissions).not_to have_received(:can_update_space?)
      end

      it 'uses the expected branch from the experiment' do
        allow(perm_permissions).to receive(:can_update_space?).and_return('not-expected')

        response = subject.can_update_space?(space_guid, org_guid)

        expect(response).to eq(true)
      end

      context 'when the control and candidate are the same' do
        space_guid = SecureRandom.uuid
        org_guid = SecureRandom.uuid

        before do
          allow(db_permissions).to receive(:can_update_space?).and_return(true)
          allow(perm_permissions).to receive(:can_update_space?).and_return(true)
        end

        it_behaves_like('match recorder',
          proc { |queryer| queryer.can_update_space?(space_guid, org_guid) },
          :can_update_space?,
          true,
          true,
          { space_guid: space_guid, org_guid: org_guid }
        )
      end

      context 'when the control and candidate are different' do
        space_guid = SecureRandom.uuid
        org_guid = SecureRandom.uuid

        before do
          allow(db_permissions).to receive(:can_update_space?).and_return(true)
          allow(perm_permissions).to receive(:can_update_space?).and_return('something wrong')
        end

        it_behaves_like('mismatch recorder',
          proc { |queryer| queryer.can_update_space?(space_guid, org_guid) },
          :can_update_space?,
          true,
          'something wrong',
          { space_guid: space_guid, org_guid: org_guid }
        )
      end
    end

    describe '#can_read_from_isolation_segment?' do
      class FakeIsolationSegment
        def initialize(guid)
          @guid = guid
        end

        def guid
          @guid
        end
      end

      let(:isolation_segment) { spy(:isolation_segment, guid: 'some-isolation-segment-guid') }

      before do
        allow(perm_permissions).to receive(:can_read_from_isolation_segment?)

        allow(db_permissions).to receive(:can_read_from_isolation_segment?).and_return(true)
        allow(db_permissions).to receive(:can_read_globally?).and_return(false)
      end

      it 'asks for #can_read_from_isolation_segment? on behalf of the current user' do
        allow(perm_permissions).to receive(:can_read_from_isolation_segment?).and_return(true)

        subject.can_read_from_isolation_segment?(isolation_segment)

        expect(db_permissions).to have_received(:can_read_from_isolation_segment?).with(isolation_segment)
        expect(perm_permissions).to have_received(:can_read_from_isolation_segment?).with(isolation_segment)
      end

      it 'skips the experiment if the user is a global reader' do
        allow(db_permissions).to receive(:can_read_globally?).and_return(true)

        subject.can_read_from_isolation_segment?(isolation_segment)

        expect(perm_permissions).not_to have_received(:can_read_from_isolation_segment?)
      end

      it 'uses the expected branch from the experiment' do
        allow(perm_permissions).to receive(:can_read_from_isolation_segment?).and_return('not-expected')

        response = subject.can_read_from_isolation_segment?(isolation_segment)

        expect(response).to eq(true)
      end

      context 'when the control and candidate are the same' do
        isolation_segment_guid = SecureRandom.uuid
        isolation_segment = FakeIsolationSegment.new(isolation_segment_guid)

        before do
          allow(db_permissions).to receive(:can_read_from_isolation_segment?).and_return(true)
          allow(perm_permissions).to receive(:can_read_from_isolation_segment?).and_return(true)
        end

        it_behaves_like('match recorder',
          proc { |queryer| queryer.can_read_from_isolation_segment?(isolation_segment) },
          :can_read_from_isolation_segment?,
          true,
          true,
          isolation_segment_guid: isolation_segment_guid
        )
      end

      context 'when the control and candidate are different' do
        isolation_segment_guid = SecureRandom.uuid
        isolation_segment = FakeIsolationSegment.new(isolation_segment_guid)

        before do
          allow(db_permissions).to receive(:can_read_from_isolation_segment?).and_return(true)
          allow(perm_permissions).to receive(:can_read_from_isolation_segment?).and_return('something wrong')
        end

        it_behaves_like('mismatch recorder',
          proc { |queryer| queryer.can_read_from_isolation_segment?(isolation_segment) },
          :can_read_from_isolation_segment?,
          true,
          'something wrong',
          isolation_segment_guid: isolation_segment_guid
        )
      end
    end

    describe '#readable_route_guids' do
      it_behaves_like 'readable guids', 'route'
    end

    describe '#can_read_route?' do
      before do
        allow(perm_permissions).to receive(:can_read_route?)

        allow(db_permissions).to receive(:can_read_route?).and_return(true)
        allow(db_permissions).to receive(:can_read_globally?).and_return(false)
      end

      it 'asks for #can_read_route? on behalf of the current user' do
        allow(perm_permissions).to receive(:can_read_route?).and_return(true)

        subject.can_read_route?(space_guid, org_guid)

        expect(db_permissions).to have_received(:can_read_route?).with(space_guid, org_guid)
        expect(perm_permissions).to have_received(:can_read_route?).with(space_guid, org_guid)
      end

      it 'skips the experiment if the user is a global reader' do
        allow(db_permissions).to receive(:can_read_globally?).and_return(true)

        subject.can_read_route?(space_guid, org_guid)

        expect(perm_permissions).not_to have_received(:can_read_route?)
      end

      it 'uses the expected branch from the experiment' do
        allow(perm_permissions).to receive(:can_read_route?).and_return('not-expected')

        response = subject.can_read_route?(space_guid, org_guid)

        expect(response).to eq(true)
      end

      context 'when the control and candidate are the same' do
        space_guid = SecureRandom.uuid
        org_guid = SecureRandom.uuid

        before do
          allow(db_permissions).to receive(:can_read_route?).and_return(true)
          allow(perm_permissions).to receive(:can_read_route?).and_return(true)
        end

        it_behaves_like 'match recorder',
          proc { |queryer| queryer.can_read_route?(space_guid, org_guid) },
          :can_read_route?,
          true,
          true,
          {
            space_guid: space_guid,
            org_guid: org_guid
          }
      end

      context 'when the control and candidate are different' do
        space_guid = SecureRandom.uuid
        org_guid = SecureRandom.uuid

        before do
          allow(db_permissions).to receive(:can_read_route?).and_return(true)
          allow(perm_permissions).to receive(:can_read_route?).and_return('something wrong')
        end

        it_behaves_like 'mismatch recorder',
          proc { |queryer| queryer.can_read_route?(space_guid, org_guid) },
          :can_read_route?,
          true,
          'something wrong',
          {
            space_guid: space_guid,
            org_guid: org_guid
          }
      end
    end

    describe '#readable_app_guids' do
      it_behaves_like 'readable guids', 'app'
    end

    describe '#readable_route_mapping_guids' do
      it_behaves_like 'readable guids', 'route_mapping'
    end

    describe '#task_readable_space_guids' do
      it 'delegates to perm (and does not check CC permissions)' do
        allow(perm_permissions).to receive(:task_readable_space_guids).and_return(['here-is-a-guid'])
        expect(subject.task_readable_space_guids).to eq(['here-is-a-guid'])
        expect(perm_permissions).to have_received(:task_readable_space_guids).once
      end
    end

    describe '#can_read_task?' do
      it 'delegates to perm (and does not check CC permissions)' do
        allow(perm_permissions).to receive(:can_read_task?).and_return true
        expect(subject.can_read_task?(space_guid: 'my-space-guid', org_guid: 'my-org-guid')).to eq true
        expect(perm_permissions).to have_received(:can_read_task?).with(space_guid: 'my-space-guid', org_guid: 'my-org-guid')
      end
    end

    describe '#readable_secret_space_guids' do
      it_behaves_like 'readable guids', 'secret_space'
    end

    describe '#readable_space_scoped_guids' do
      it_behaves_like 'readable guids', 'space_scoped_space'
    end
  end
end
