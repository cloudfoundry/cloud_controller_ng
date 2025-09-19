# usage: pipe this script into bin/console on a cc-worker vm

NUM_JOBS = 1
DELAY = 1

puts "Generating #{NUM_JOBS} dummy job(s) with delay of #{DELAY} seconds"
enqueuer = VCAP::CloudController::Jobs::Enqueuer.new(queue: VCAP::CloudController::Jobs::Queues.generic)
start_time = Time.now
NUM_JOBS.times do
  dummy_job = VCAP::CloudController::Jobs::Runtime::BlobstoreDelete.new('00000000-0000-0000-0000-000000000000/0000000000000000000000000000000000000000', :droplet_blobstore)
  enqueuer.enqueue(dummy_job)
  sleep DELAY
end
puts "Generated #{NUM_JOBS} dummy job(s) in #{Time.now - start_time} seconds"
