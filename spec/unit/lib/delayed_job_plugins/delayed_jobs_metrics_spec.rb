require 'spec_helper'

RSpec.describe DelayedJobMetrics::Plugin do
  let(:prometheus) { instance_double(VCAP::CloudController::Metrics::PrometheusUpdater) }
  let(:worker) { instance_double(Delayed::Worker, name: 'test_worker') }

  before do
    allow(CloudController::DependencyLocator.instance).to receive(:cc_worker_prometheus_updater).and_return(prometheus)
    allow(prometheus).to receive(:update_histogram_metric)
  end

  it 'loads the plugin' do
    expect(Delayed::Worker.plugins).to include(DelayedJobMetrics::Plugin)
  end

  it 'processes a job and updates Prometheus metrics with simulated time delay' do
    Timecop.freeze(Time.now) do
      events_cleanup_job = VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(10_000)
      VCAP::CloudController::Jobs::Enqueuer.new({ queue: VCAP::CloudController::Jobs::Queues.generic }).enqueue(events_cleanup_job)

      events_cleanup_job = Delayed::Job.last
      expect(events_cleanup_job).not_to be_nil

      allow(Time).to receive(:now).and_return(Time.now + 10.seconds)
      worker = Delayed::Worker.new
      worker.name = 'test_worker'
      worker.work_off(1)

      expect(prometheus).to have_received(:update_histogram_metric).with(
        :cc_job_pickup_delay_seconds,
        be_within(0.5).of(10.0),
        labels: { queue: VCAP::CloudController::Jobs::Queues.generic, worker: 'test_worker' }
      ).once

      expect(prometheus).to have_received(:update_histogram_metric).with(
        :cc_job_duration_seconds,
        kind_of(Numeric),
        labels: { queue: VCAP::CloudController::Jobs::Queues.generic, worker: 'test_worker' }
      ).once
    end
  end
end
