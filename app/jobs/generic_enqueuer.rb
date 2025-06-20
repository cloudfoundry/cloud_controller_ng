module VCAP::CloudController
  module Jobs
    REDUCED_PRIORITY = 50

    class GenericEnqueuer < Enqueuer
      def self.shared(priority: nil)
        stored_instance = Thread.current[:generic_enqueuer]
        return stored_instance if stored_instance && priority.nil?

        new_instance = new(queue: Jobs::Queues.generic, priority: priority)
        Thread.current[:generic_enqueuer] ||= new_instance
        new_instance
      end

      def self.reset!
        Thread.current[:generic_enqueuer] = nil
      end
    end
  end
end
