require 'cloud_controller/benchmark/blobstore'

namespace :benchmarks do
  desc 'Perform blobstore benchmark'
  task perform_blobstore_benchmark: :environment do
    RakeConfig.context = :blobstore_benchmarks
    BoshErrandEnvironment.new(RakeConfig.config).setup_environment do
      VCAP::CloudController::Benchmark::Blobstore.new.perform
    end
  end
end
