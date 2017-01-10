require 'diego/bbs/bbs'

module Diego
  module ActionBuilder
    extend Forwardable

    ACTION_TYPE_MAP = {
      Bbs::Models::DownloadAction     => :download_action,
      Bbs::Models::EmitProgressAction => :emit_progress_action,
      Bbs::Models::RunAction          => :run_action,
      Bbs::Models::UploadAction       => :upload_action,
      Bbs::Models::TimeoutAction      => :timeout_action,
      Bbs::Models::TryAction          => :try_action,
      Bbs::Models::ParallelAction     => :parallel_action,
      Bbs::Models::SerialAction       => :serial_action,
      Bbs::Models::CodependentAction  => :codependent_action,
    }.freeze

    class << self
      def action_type(action)
        ACTION_TYPE_MAP[action.class]
      end

      def action(action)
        return action if action_already_wrapped?(action)
        Bbs::Models::Action.new(action_type(action) => action)
      end

      def serial(actions)
        action(Bbs::Models::SerialAction.new(actions: actions.map { |a| action(a) }))
      end

      def parallel(actions)
        action(Bbs::Models::ParallelAction.new(actions: actions.map { |a| action(a) }))
      end

      def timeout(action, timeout_ms:)
        action(Bbs::Models::TimeoutAction.new(action: action(action), timeout_ms: timeout_ms))
      end

      def try_action(action)
        action(Bbs::Models::TryAction.new(action: action(action)))
      end

      def emit_progress(action, start_message:, success_message:, failure_message_prefix:)
        action(Bbs::Models::EmitProgressAction.new(
                 action:                 action(action),
                 start_message:          start_message,
                 success_message:        success_message,
                 failure_message_prefix: failure_message_prefix))
      end

      def codependent(actions)
        action(::Diego::Bbs::Models::CodependentAction.new(actions: actions.map { |a| action(a) }))
      end

      private

      def action_already_wrapped?(action)
        action.class == Bbs::Models::Action
      end
    end

    def_delegators ::Diego::ActionBuilder,
      :action_type,
      :action,
      :serial,
      :parallel,
      :timeout,
      :emit_progress,
      :codependent,
      :try_action
  end
end
