module DelayedJobMetrics
  class Plugin < Delayed::Plugin
    class << self
      attr_writer :prometheus

      def prometheus
        @prometheus ||= CloudController::DependencyLocator.instance.prometheus_updater
      end
    end

    callbacks do |lifecycle|
      lifecycle.after(:perform) do |worker, job|
        labels = { queue: job.queue, worker: worker.name }

        job_pickup_delay = job.locked_at && job.run_at ? job.locked_at - job.run_at : nil
        prometheus.update_histogram_metric(:cc_job_pickup_delay_seconds, job_pickup_delay, labels:) if job_pickup_delay

        job_duration = job.locked_at ? Time.now.utc - job.locked_at : nil
        prometheus.update_histogram_metric(:cc_job_duration_seconds, job_duration, labels:) if job_duration
      end
    end
  end
end

Delayed::Worker.plugins << DelayedJobMetrics::Plugin
