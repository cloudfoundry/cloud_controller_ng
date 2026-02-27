#!/usr/bin/env ruby
# Smart converter - attempts to auto-detect and add required dependencies

require 'fileutils'

# Next batch of 30 candidates (after the first 30 we already tried)
CANDIDATES = [
  'spec/unit/lib/cloud_controller/blobstore/client_provider_spec.rb',
  'spec/unit/lib/cloud_controller/diego/protocol/open_process_ports_spec.rb',
  'spec/unit/lib/services/service_brokers/v2/errors/service_broker_bad_response_spec.rb',
  'spec/unit/lib/services/service_brokers/v2/errors/service_broker_conflict_spec.rb',
  'spec/unit/lib/cloud_controller/telemetry_logger_spec.rb',
  'spec/unit/lib/cloud_controller/diego/protocol/routing_info_spec.rb',
  'spec/unit/lib/cloud_controller/diego/lifecycles/buildpack_info_spec.rb',
  'spec/unit/lib/cloud_controller/diego/lifecycles/app_buildpack_lifecycle_spec.rb',
  'spec/unit/lib/cloud_controller/diego/lifecycles/app_docker_lifecycle_spec.rb',
  'spec/unit/lib/cloud_controller/diego/lifecycles/buildpack_lifecycle_spec.rb',
  'spec/unit/lib/cloud_controller/diego/lifecycles/docker_lifecycle_spec.rb',
  'spec/unit/lib/cloud_controller/resource_pool_spec.rb',
  'spec/unit/lib/cloud_controller/paging/pagination_options_spec.rb',
  'spec/unit/lib/cloud_controller/diego/protocol/app_volume_mounts_spec.rb',
  'spec/unit/lib/services/service_brokers/v2/orphan_mitigator_spec.rb',
  'spec/unit/lib/cloud_controller/app_observer_spec.rb',
  'spec/unit/lib/rest_controller/order_applicator_spec.rb',
  'spec/unit/lib/cloud_controller/deployment_updater/updater_spec.rb',
  'spec/unit/lib/cloud_controller/clock_spec.rb',
  'spec/unit/lib/cloud_controller/diego/protocol/container_network_info_spec.rb',
  'spec/unit/lib/cloud_controller/diego/lifecycles/kpack_lifecycle_spec.rb',
  'spec/unit/lib/cloud_controller/diego/protocol_spec.rb',
  'spec/unit/lib/cloud_controller/diego/v3/messenger_spec.rb',
  'spec/unit/lib/cloud_controller/diego/v3/protocol/task_protocol_spec.rb',
  'spec/unit/lib/cloud_controller/diego/buildpack/lifecycle_protocol_spec.rb',
  'spec/unit/lib/cloud_controller/diego/buildpack/buildpack_entry_generator_spec.rb',
  'spec/unit/lib/steno/codec_rfc3339_spec.rb',
  'spec/unit/lib/services/service_key_credential_binding_manager_spec.rb',
  'spec/unit/lib/services/service_brokers/service_client_provider_spec.rb',
  'spec/unit/lib/cloud_controller/diego/docker/lifecycle_protocol_spec.rb',
]

def find_source_file(spec_file)
  # Convert spec path to likely source path
  source = spec_file
    .gsub('spec/unit/lib/', 'lib/')
    .gsub('_spec.rb', '.rb')

  File.exist?(source) ? source : nil
end

def extract_class_name(content)
  # Try to find the main class being tested
  if content =~ /RSpec\.describe\s+([A-Z:][A-Za-z0-9:]*)/
    $1
  elsif content =~ /module\s+([A-Z:][A-Za-z0-9:]*)/
    $1
  end
end

def class_to_require_path(class_name)
  # Convert ClassName::Foo to class_name/foo
  parts = class_name.split('::')
  parts = parts.drop(1) if parts.first == 'VCAP' # Skip VCAP prefix
  parts.map { |p| p.gsub(/([a-z])([A-Z])/, '\1_\2').downcase }.join('/')
end

puts "Smart Batch Converter - Attempting to add required dependencies"
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

  # Backup
  backup = "#{file}.bak"
  File.write(backup, content)

  # Try simple conversion first (no extra requires)
  new_content = content.sub(/require ['"]spec_helper['"]/, "require 'lightweight_spec_helper'")
  File.write(file, new_content)

  system("bundle exec rspec #{file} --format progress > /dev/null 2>&1")

  if $?.success?
    puts "✅ (simple)"
    File.delete(backup)
    results[:success] << { file: file, method: 'simple' }
    next
  end

  # Simple didn't work, try adding source file require
  source_file = find_source_file(file)
  if source_file
    require_path = source_file.gsub('lib/', '').gsub('.rb', '')
    new_content = content.sub(
      /require ['"]spec_helper['"]/,
      "require 'lightweight_spec_helper'\nrequire '#{require_path}'"
    )
    File.write(file, new_content)

    system("bundle exec rspec #{file} --format progress > /dev/null 2>&1")

    if $?.success?
      puts "✅ (with require)"
      File.delete(backup)
      results[:success] << { file: file, method: 'with_require' }
      next
    end
  end

  # Didn't work, revert
  puts "❌ FAILED"
  File.write(file, content)
  File.delete(backup)
  results[:failed] << file
end

puts "\n" + "=" * 80
puts "RESULTS"
puts "=" * 80
puts "✅ Success: #{results[:success].count}"
puts "   - Simple conversions: #{results[:success].count { |r| r[:method] == 'simple' }}"
puts "   - With requires: #{results[:success].count { |r| r[:method] == 'with_require' }}"
puts "❌ Failed:  #{results[:failed].count}"
puts "⏭️  Skipped: #{results[:skipped].count}"

if results[:success].any?
  puts "\n✅ Successfully converted:"
  results[:success].each do |r|
    method_label = r[:method] == 'simple' ? '' : ' (added require)'
    puts "  - #{r[:file].gsub('spec/unit/lib/', '')}#{method_label}"
  end

  savings = results[:success].count * 6.65
  puts "\nEstimated savings: #{savings.round(1)} seconds per test run"
  puts "Cumulative total: #{(12 + results[:success].count)} files = #{((12 + results[:success].count) * 6.65).round(1)} seconds"
end

if results[:failed].any?
  puts "\n❌ Failed conversions (may need Config or other dependencies):"
  results[:failed].first(10).each { |f| puts "  - #{f.gsub('spec/unit/lib/', '')}" }
  puts "  ... and #{results[:failed].count - 10} more" if results[:failed].count > 10
end

puts "\n" + "=" * 80
