class BeforeEnqueueHook < Delayed::Plugin
  callbacks do |lifecycle|
    lifecycle.before(:enqueue) do |job|
      job.payload_object.try(:before_enqueue, job)
    end
  end
end
Delayed::Worker.plugins << BeforeEnqueueHook
