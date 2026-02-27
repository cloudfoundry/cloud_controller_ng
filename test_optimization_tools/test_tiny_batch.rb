#!/usr/bin/env ruby
# Try the 10 smallest, most promising candidates

CANDIDATES = [
  'spec/unit/lib/services/sso/commands/delete_client_command_spec.rb',
  'spec/unit/lib/sequel_plugins/vcap_normalization_spec.rb',
  'spec/unit/lib/sequel/extensions/query_length_logging_spec.rb',
  'spec/unit/lib/services/sso/commands/update_client_command_spec.rb',
  'spec/unit/lib/services/sso/commands/create_client_command_spec.rb',
  'spec/unit/lib/cloud_controller/random_route_generator_spec.rb',
  'spec/unit/lib/cloud_controller/adjective_noun_generator_spec.rb',
  'spec/unit/lib/cloud_controller/blobstore/blob_key_generator_spec.rb',
  'spec/unit/lib/services/service_brokers/v2/errors/service_broker_api_timeout_spec.rb',
  'spec/unit/lib/cloud_controller/diego/process_guid_spec.rb',
  'spec/unit/lib/cloud_controller/diego/staging_action_builder_spec.rb',
  'spec/unit/lib/cloud_controller/diego/lifecycle_protocol_spec.rb',
  'spec/unit/lib/cloud_controller/routing_api/disabled_routing_api_client_spec.rb',
  'spec/unit/lib/services/service_brokers/v2/parameters_schema_spec.rb',
  'spec/unit/lib/cloud_controller/diego/droplet_url_generator_spec.rb',
]

puts "Testing 15 Very Small Candidates"
puts "=" * 80

results = { success: [], failed: [], skipped: [] }

CANDIDATES.each_with_index do |file, idx|
  print "[#{idx+1}/#{CANDIDATES.count}] #{file.split('/').last}... "

  unless File.exist?(file)
    puts "❌ NOT FOUND"
    results[:skipped] << file
    next
  end

  content = File.read(file)
  unless content.match?(/require ['"]spec_helper['"]/)
    puts "⏭️  SKIP"
    results[:skipped] << file
    next
  end

  # Test original
  system("bundle exec rspec #{file} > /dev/null 2>&1")
  unless $?.success?
    puts "❌ ORIG FAIL"
    results[:skipped] << file
    next
  end

  # Backup and try simple conversion
  backup = "#{file}.bak"
  File.write(backup, content)

  new_content = content.sub(/require ['"]spec_helper['"]/, "require 'lightweight_spec_helper'")
  File.write(file, new_content)

  system("bundle exec rspec #{file} > /dev/null 2>&1")

  if $?.success?
    puts "✅"
    File.delete(backup)
    results[:success] << file
  else
    puts "❌"
    File.write(file, content)
    File.delete(backup)
    results[:failed] << file
  end
end

puts "\n" + "=" * 80
puts "✅ Success: #{results[:success].count}"
puts "❌ Failed:  #{results[:failed].count}"
puts "⏭️  Skipped: #{results[:skipped].count}"

if results[:success].any?
  puts "\n✅ Converted:"
  results[:success].each { |f| puts "  - #{f.split('/').last}" }
  puts "\nSavings: #{(results[:success].count * 6.65).round(1)}s per run"
  puts "New total: #{(13 + results[:success].count)} files = #{((13 + results[:success].count) * 6.65).round(1)}s saved"
end
