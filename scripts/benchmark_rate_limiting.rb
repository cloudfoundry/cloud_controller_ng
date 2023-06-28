# usage: pipe this script into bin/console on the api vm
# this script logs to stderr, thus you might want to redirect stdout to /dev/null

NUM_USERS = 1000
NUM_REQUESTS_PER_USER = 1000

logger = Logger.new($stderr)

rate_limiter = CloudFoundry::Middleware::RateLimiter::EXPIRING_REQUEST_COUNTER
rate_limiter_v2 = CloudFoundry::Middleware::RateLimiterV2API::EXPIRING_REQUEST_COUNTER
service_broker_rate_limiter = CloudFoundry::Middleware::ServiceBrokerRateLimiter::CONCURRENT_REQUEST_COUNTER
reset_interval_in_minutes = 60
max_concurrent_requests = 10

logger.info("Creating #{NUM_USERS} random user guids...")
user_guids = []
NUM_USERS.times do
  user_guids << SecureRandom.uuid
end
logger.info('    ... done.')

logger.info('Running benchmark...')
result = Benchmark.measure do
  NUM_REQUESTS_PER_USER.times do |i|
    user_guids.each do |user_guid|
      rate_limiter.increment(user_guid, reset_interval_in_minutes, logger)
      rate_limiter_v2.increment(user_guid, reset_interval_in_minutes, logger)
      service_broker_rate_limiter.try_increment?(user_guid, max_concurrent_requests, logger)
      service_broker_rate_limiter.decrement(user_guid, logger)
    end

    completion_percentage = i.to_f / NUM_REQUESTS_PER_USER * 100
    if completion_percentage % 10 == 0
      logger.info("    (#{completion_percentage.to_i}% completed)")
    end
  end
end
logger.info('    ... done.')

num_rate_limit_events = 4 * NUM_USERS * NUM_REQUESTS_PER_USER
logger.info('Results:')
logger.info("    User CPU time     =  #{sprintf('%.1f', result.utime)}s  (per rate limit event: #{sprintf('%.3f', result.utime / num_rate_limit_events * 1000)}ms)")
logger.info("    System CPU time   =  #{sprintf('%.1f', result.stime)}s  (per rate limit event: #{sprintf('%.3f', result.stime / num_rate_limit_events * 1000)}ms)")
logger.info("    Total time        =  #{sprintf('%.1f', result.total)}s  (per rate limit event: #{sprintf('%.3f', result.total / num_rate_limit_events * 1000)}ms)")
logger.info("    Elapsed real time =  #{sprintf('%.1f', result.real)}s  (per rate limit event: #{sprintf('%.3f', result.real / num_rate_limit_events * 1000)}ms)")
