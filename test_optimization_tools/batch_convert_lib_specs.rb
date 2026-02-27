#!/usr/bin/env ruby
# Batch convert lib specs to lightweight_spec_helper

# Top 30 smallest candidates from analysis
CANDIDATES = [
  'spec/unit/lib/cloud_controller/blobstore/null_client_spec.rb',
  'spec/unit/lib/vcap/stats_spec.rb',
  'spec/unit/lib/services/sso/commands/claim_client_command_spec.rb',
  'spec/unit/lib/services/sso/commands/unclaim_client_command_spec.rb',
  'spec/unit/lib/rest_controller/preloaded_object_serializer_spec.rb',
  'spec/unit/lib/cloud_controller/logs/steno_io_spec.rb',
  'spec/unit/lib/cloud_controller/blob_sender/default_blob_sender_spec.rb',
  'spec/unit/lib/sequel/extensions/request_query_metrics_spec.rb',
  'spec/unit/lib/cloud_controller/clock/distributed_scheduler_spec.rb',
  'spec/unit/lib/services/service_brokers/null_client_spec.rb',
  'spec/unit/lib/services/service_brokers/v2/errors/async_required_spec.rb',
  'spec/unit/lib/services/service_brokers/v2/errors/app_required_spec.rb',
  'spec/unit/lib/fluent_emitter_spec.rb',
  'spec/unit/lib/services/service_brokers/v2/errors/service_broker_response_malformed_spec.rb',
  'spec/unit/lib/services/service_brokers/v2/errors/service_broker_api_authentication_failed_spec.rb',
  'spec/unit/lib/cloud_controller/blob_sender/nginx_blob_sender_spec.rb',
  'spec/unit/lib/cloud_controller/user_audit_info_spec.rb',
  'spec/unit/lib/cloud_controller/diego/desire_app_handler_spec.rb',
  'spec/unit/lib/cloud_controller/controller_factory_spec.rb',
  'spec/unit/lib/database/bigint_migration_spec.rb',
  'spec/unit/lib/delayed_job_plugins/delayed_jobs_metrics_spec.rb',
  'spec/unit/lib/locket/lock_worker_spec.rb',
  'spec/unit/lib/cloud_controller/metrics/request_metrics_spec.rb',
  'spec/unit/lib/cloud_controller/api_metrics_webserver_spec.rb',
  'spec/unit/lib/bosh_errand_environment_spec.rb',
  'spec/unit/lib/services/service_brokers/v2/errors/maintenance_info_conflict_spec.rb',
  'spec/unit/lib/services/service_brokers/v2/service_binding_schema_spec.rb',
  'spec/unit/lib/services/service_brokers/validation_errors_formatter_spec.rb',
  'spec/unit/lib/cloud_controller/diego/task_environment_variable_collector_spec.rb',
  'spec/unit/lib/rest_controller/common_params_spec.rb',
]

puts "Batch Converting lib Specs to lightweight_spec_helper"
puts "=" * 80
puts "Testing #{CANDIDATES.count} candidates..."
puts

results = { success: [], failed: [], skipped: [] }

CANDIDATES.each_with_index do |file, idx|
  print "[#{idx+1}/#{CANDIDATES.count}] #{file.gsub('spec/unit/lib/', '')}... "

  unless File.exist?(file)
    puts "❌ NOT FOUND"
    results[:skipped] << { file: file, reason: 'not found' }
    next
  end

  content = File.read(file)
  unless content.match?(/require ['"]spec_helper['"]/)
    puts "⏭️  ALREADY CONVERTED"
    results[:skipped] << { file: file, reason: 'already converted' }
    next
  end

  # Test original
  system("bundle exec rspec #{file} --format progress > /dev/null 2>&1")
  unless $?.success?
    puts "❌ ORIGINALLY FAILING"
    results[:skipped] << { file: file, reason: 'originally failing' }
    next
  end

  # Backup and convert
  backup = "#{file}.bak"
  File.write(backup, content)

  new_content = content.sub(/require ['"]spec_helper['"]/, "require 'lightweight_spec_helper'")
  File.write(file, new_content)

  # Test converted
  system("bundle exec rspec #{file} --format progress > /dev/null 2>&1")

  if $?.success?
    puts "✅"
    File.delete(backup)
    results[:success] << file
  else
    puts "❌ FAILED CONVERSION"
    File.write(file, content)
    File.delete(backup)
    results[:failed] << file
  end
end

puts "\n" + "=" * 80
puts "RESULTS"
puts "=" * 80
puts "✅ Success: #{results[:success].count}"
puts "❌ Failed:  #{results[:failed].count}"
puts "⏭️  Skipped: #{results[:skipped].count}"

if results[:success].any?
  puts "\n✅ Successfully converted:"
  results[:success].each { |f| puts "  - #{f.gsub('spec/unit/lib/', '')}" }

  savings = results[:success].count * 6.65
  puts "\nEstimated savings: #{savings.round(1)} seconds per test run"
end

if results[:failed].any?
  puts "\n❌ Failed conversions (need manual review):"
  results[:failed].each { |f| puts "  - #{f.gsub('spec/unit/lib/', '')}" }
end

puts "\n" + "=" * 80
