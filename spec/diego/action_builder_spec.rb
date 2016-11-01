require 'diego/action_builder'

module Diego
  RSpec.describe ActionBuilder do
    describe 'action_type' do
      it 'knows timeout action' do
        expect(described_class.action_type(Bbs::Models::TimeoutAction.new)).to eq(:timeout_action)
      end

      it 'knows download action' do
        expect(described_class.action_type(Bbs::Models::DownloadAction.new)).to eq(:download_action)
      end

      it 'knows upload action' do
        expect(described_class.action_type(Bbs::Models::UploadAction.new)).to eq(:upload_action)
      end

      it 'knows emit progress action' do
        expect(described_class.action_type(Bbs::Models::EmitProgressAction.new)).to eq(:emit_progress_action)
      end

      it 'knows run action' do
        expect(described_class.action_type(Bbs::Models::RunAction.new)).to eq(:run_action)
      end

      it 'knows try action' do
        expect(described_class.action_type(Bbs::Models::TryAction.new)).to eq(:try_action)
      end

      it 'knows parallel action' do
        expect(described_class.action_type(Bbs::Models::ParallelAction.new)).to eq(:parallel_action)
      end

      it 'knows serial action' do
        expect(described_class.action_type(Bbs::Models::SerialAction.new)).to eq(:serial_action)
      end

      it 'knows codependent action' do
        expect(described_class.action_type(Bbs::Models::CodependentAction.new)).to eq(:codependent_action)
      end
    end

    describe 'action' do
      it 'wraps an unwrapped action' do
        timeout_action = Bbs::Models::TimeoutAction.new
        action         = described_class.action(timeout_action)
        expect(action).to be_a(Bbs::Models::Action)
        expect(action[:timeout_action]).to eq(timeout_action)
      end

      it 'wraps an unwrapped action idempotently' do
        timeout_action = Bbs::Models::TimeoutAction.new

        action = described_class.action(timeout_action)
        expect(action).to be_a(Bbs::Models::Action)
        expect(action[:timeout_action]).to eq(timeout_action)

        idempotent_action = described_class.action(action)
        expect(idempotent_action).to be_a(Bbs::Models::Action)
        expect(idempotent_action[:timeout_action]).to eq(timeout_action)
      end
    end

    describe 'serial' do
      it 'wraps a list of actions in a serial action' do
        action1 = Bbs::Models::TimeoutAction.new
        action2 = Bbs::Models::TimeoutAction.new

        serial_action = described_class.serial([action1, action2])

        expect(serial_action).to be_a(Bbs::Models::Action)
        expect(serial_action[:serial_action]).to be_a(Bbs::Models::SerialAction)
        expect(serial_action[:serial_action].actions).to match_array([described_class.action(action1), described_class.action(action2)])
      end
    end

    describe 'parallel' do
      it 'wraps a list of actions in a parallel action' do
        action1 = Bbs::Models::TimeoutAction.new
        action2 = Bbs::Models::TimeoutAction.new

        serial_action = described_class.parallel([action1, action2])

        expect(serial_action).to be_a(Bbs::Models::Action)
        expect(serial_action[:parallel_action]).to be_a(Bbs::Models::ParallelAction)
        expect(serial_action[:parallel_action].actions).to match_array([described_class.action(action1), described_class.action(action2)])
      end
    end

    describe 'timeout' do
      it 'wraps an action in a timeout action' do
        action = Bbs::Models::RunAction.new

        timeout_action = described_class.timeout(action, timeout_ms: 30)

        expect(timeout_action).to be_a(Bbs::Models::Action)
        expect(timeout_action[:timeout_action]).to be_a(Bbs::Models::TimeoutAction)
        expect(timeout_action[:timeout_action].action).to be_a(Bbs::Models::Action)
        expect(timeout_action[:timeout_action].action).to eq(described_class.action(action))
        expect(timeout_action[:timeout_action].timeout_ms).to eq(30)
      end
    end

    describe 'emit_progress' do
      it 'wraps an action in a timeout action' do
        action = Bbs::Models::RunAction.new

        emit_progress_action = described_class.emit_progress(action, start_message: 'start', success_message: 'success', failure_message_prefix: 'failed: ')

        expect(emit_progress_action).to be_a(Bbs::Models::Action)
        expect(emit_progress_action[:emit_progress_action]).to be_a(Bbs::Models::EmitProgressAction)
        expect(emit_progress_action[:emit_progress_action].action).to be_a(Bbs::Models::Action)
        expect(emit_progress_action[:emit_progress_action].action).to eq(described_class.action(action))
        expect(emit_progress_action[:emit_progress_action].start_message).to eq('start')
        expect(emit_progress_action[:emit_progress_action].success_message).to eq('success')
        expect(emit_progress_action[:emit_progress_action].failure_message_prefix).to eq('failed: ')
      end
    end
  end
end
