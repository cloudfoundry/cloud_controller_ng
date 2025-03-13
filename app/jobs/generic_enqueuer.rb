module VCAP::CloudController
  module Jobs
    REDUCED_PRIORITY = 50

    class GenericEnqueuer < Enqueuer
      def self.shared(priority: nil)
        stored_instance = Thread.current[:generic_enqueuer]
        puts "[#{Process.pid} | #{Thread.current.object_id}] Shared enqueuer accessed: #{stored_instance} | Priority: #{priority}"
        return stored_instance if stored_instance && priority.nil?

        new_instance = new(queue: Jobs::Queues.generic, priority: priority)
        Thread.current[:generic_enqueuer] ||= new_instance
        new_instance
      end

      def self.reset!
        puts "Resetting GenericEnqueuer instance #{Thread.current[:generic_enqueuer]} in process: #{Process.pid} | Thread: #{Thread.current.object_id}"
        Thread.current[:generic_enqueuer] = nil
      end
    end
  end
end
