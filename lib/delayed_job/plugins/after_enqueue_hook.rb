class AfterEnqueueHook < Delayed::Plugin
  callbacks do |lifecycle|
    lifecycle.after(:enqueue) do |job|
      job.payload_object.try(:after_enqueue, job)
    end
  end
end
Delayed::Worker.plugins << AfterEnqueueHook
