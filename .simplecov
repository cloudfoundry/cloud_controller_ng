# frozen_string_literal: true

# Namespaced command_name + long merge_timeout so spec:all's three invocations merge, not overwrite.
SimpleCov.configure do
  skip '/spec/'
  skip '/errors/'
  skip '/docs/'

  merging true
  merge_timeout 3600

  suite = ENV.fetch('COVERAGE_SUITE', 'default')
  worker = ENV['TEST_ENV_NUMBER'].to_s
  worker = '1' if worker.empty?
  command_name "#{suite}-#{worker}"
end
