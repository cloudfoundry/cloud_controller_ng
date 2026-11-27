require 'lightweight_spec_helper'
require 'prometheus/client'
require 'prometheus/client/data_stores/direct_file_store'
require 'cloud_controller/metrics/custom_process_id'

RSpec.describe 'Local worker metric isolation' do
  let(:tmpdir) { Dir.mktmpdir('worker-metrics') }

  around do |example|
    original_store = Prometheus::Client.config.data_store
    original_index = ENV.fetch('INDEX', nil)
    original_process_type = ENV.fetch('PROCESS_TYPE', nil)
    Prometheus::Client.config.data_store = Prometheus::Client::DataStores::DirectFileStore.new(dir: tmpdir)
    example.run
  ensure
    Prometheus::Client.config.data_store = original_store
    ENV['INDEX'] = original_index
    ENV['PROCESS_TYPE'] = original_process_type
    FileUtils.remove_entry(tmpdir)
  end

  it 'keeps separate metric files for worker indexes sharing the same process ID' do
    ENV['PROCESS_TYPE'] = 'puma_worker'
    ENV['INDEX'] = '1'
    first_registry = Prometheus::Client::Registry.new
    first_counter = first_registry.counter(:cc_storage_cli_operations_total, docstring: 'Storage CLI operations', labels: %i[operation exit_code])
    first_counter.increment(labels: { operation: 'put', exit_code: '0' })

    ENV['INDEX'] = '2'
    second_registry = Prometheus::Client::Registry.new
    second_counter = second_registry.counter(:cc_storage_cli_operations_total, docstring: 'Storage CLI operations', labels: %i[operation exit_code])
    second_counter.increment(by: 2, labels: { operation: 'put', exit_code: '0' })

    expect(Dir.glob(File.join(tmpdir, '*.bin')).size).to eq(2)
    expect(first_counter.values).to eq({ { operation: 'put', exit_code: '0' } => 3.0 })
  end

  it 'keeps API PIDs separate from equal worker indexes' do
    allow(Process).to receive(:pid).and_return(2)
    ENV['PROCESS_TYPE'] = 'main'
    ENV.delete('INDEX')
    api_registry = Prometheus::Client::Registry.new
    api_counter = api_registry.counter(:cc_storage_cli_operations_total, docstring: 'Storage CLI operations', labels: %i[operation exit_code])
    api_counter.increment(labels: { operation: 'put', exit_code: '0' })

    ENV['INDEX'] = '2'
    ENV['PROCESS_TYPE'] = 'puma_worker'
    worker_registry = Prometheus::Client::Registry.new
    worker_counter = worker_registry.counter(:cc_storage_cli_operations_total, docstring: 'Storage CLI operations', labels: %i[operation exit_code])
    worker_counter.increment(by: 2, labels: { operation: 'put', exit_code: '0' })

    expect(Dir.glob(File.join(tmpdir, '*.bin')).size).to eq(2)
    expect(api_counter.values).to eq({ { operation: 'put', exit_code: '0' } => 3.0 })
  end

  it 'reuses existing generic-worker metric files after a restart' do
    ENV['PROCESS_TYPE'] = 'cc-worker'
    allow(Process).to receive(:pid).and_return(1)
    ENV.delete('INDEX')
    legacy_registry = Prometheus::Client::Registry.new
    legacy_gauge = legacy_registry.gauge(:cc_acquired_db_connections_total, docstring: 'Active DB connections', labels: [:process_type])
    legacy_gauge.set(7, labels: { process_type: 'cc-worker' })

    ENV['INDEX'] = '1'
    restarted_registry = Prometheus::Client::Registry.new
    restarted_gauge = restarted_registry.gauge(:cc_acquired_db_connections_total, docstring: 'Active DB connections', labels: [:process_type])
    restarted_gauge.set(0, labels: { process_type: 'cc-worker' })

    expect(restarted_gauge.values).to eq({ { pid: '1', process_type: 'cc-worker' } => 0.0 })
    expect(Dir.glob(File.join(tmpdir, '*.bin')).size).to eq(1)
  end
end
