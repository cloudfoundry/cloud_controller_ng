#!/usr/bin/env ruby

# Script to convert spec_helper to lightweight_spec_helper for eligible files

CANDIDATES = [
  'spec/unit/lib/structured_error_spec.rb',
  'spec/unit/lib/http_response_error_spec.rb',
  'spec/unit/lib/http_request_error_spec.rb',
  'spec/unit/lib/index_stopper_spec.rb',
  'spec/unit/lib/cloud_controller/diego/docker/docker_uri_converter_spec.rb',
  'spec/unit/lib/cloud_controller/diego/failure_reason_sanitizer_spec.rb',
  'spec/unit/lib/cloud_controller/database_uri_generator_spec.rb',
  'spec/unit/lib/cloud_controller/url_secret_obfuscator_spec.rb',
  'spec/unit/lib/cloud_controller/encryptor_spec.rb',
  'spec/unit/lib/utils/uri_utils_spec.rb',
  'spec/unit/lib/vcap/digester_spec.rb',
  'spec/unit/lib/vcap/json_message_spec.rb',
  'spec/unit/lib/cloud_controller/user_audit_info_spec.rb',
  'spec/unit/lib/services/service_brokers/v2/errors/async_required_spec.rb',
  'spec/unit/lib/vcap/host_system_spec.rb',
  'spec/unit/lib/vcap/request_spec.rb',
  'spec/unit/lib/rest_controller/common_params_spec.rb',
  'spec/unit/lib/services/service_brokers/v2/http_response_spec.rb',
  'spec/unit/lib/steno/codec_rfc3339_spec.rb',
  'spec/unit/lib/uaa/uaa_token_decoder_spec.rb',
  'spec/unit/lib/cloud_controller/clock/job_timeout_calculator_spec.rb',
  'spec/unit/lib/vcap/stats_spec.rb',
  'spec/unit/lib/services/validation_errors_spec.rb',
  'spec/unit/lib/cloud_controller/rack_app_builder_spec.rb',
  'spec/unit/lib/rest_controller/order_applicator_spec.rb',
]

# Map of spec files to required source files
REQUIRE_MAP = {
  'spec/unit/lib/structured_error_spec.rb' => 'cloud_controller/structured_error',
  'spec/unit/lib/http_response_error_spec.rb' => 'cloud_controller/http_response_error',
  'spec/unit/lib/http_request_error_spec.rb' => 'cloud_controller/http_request_error',
  'spec/unit/lib/index_stopper_spec.rb' => 'cloud_controller/index_stopper',
  'spec/unit/lib/cloud_controller/diego/docker/docker_uri_converter_spec.rb' => 'cloud_controller/diego/docker/docker_uri_converter',
  'spec/unit/lib/cloud_controller/diego/failure_reason_sanitizer_spec.rb' => 'cloud_controller/diego/failure_reason_sanitizer',
  'spec/unit/lib/cloud_controller/database_uri_generator_spec.rb' => 'cloud_controller/database_uri_generator',
  'spec/unit/lib/cloud_controller/url_secret_obfuscator_spec.rb' => 'cloud_controller/url_secret_obfuscator',
  'spec/unit/lib/cloud_controller/encryptor_spec.rb' => 'cloud_controller/encryptor',
  'spec/unit/lib/utils/uri_utils_spec.rb' => 'utils/uri_utils',
  'spec/unit/lib/vcap/digester_spec.rb' => 'vcap/digester',
  'spec/unit/lib/vcap/json_message_spec.rb' => 'vcap/json_message',
  'spec/unit/lib/cloud_controller/user_audit_info_spec.rb' => 'cloud_controller/user_audit_info',
  'spec/unit/lib/services/service_brokers/v2/errors/async_required_spec.rb' => 'services/service_brokers/v2/errors/async_required',
  'spec/unit/lib/vcap/host_system_spec.rb' => 'vcap/host_system',
  'spec/unit/lib/vcap/request_spec.rb' => 'vcap/request',
  'spec/unit/lib/rest_controller/common_params_spec.rb' => 'rest_controller/common_params',
  'spec/unit/lib/services/service_brokers/v2/http_response_spec.rb' => 'services/service_brokers/v2/http_response',
  'spec/unit/lib/steno/codec_rfc3339_spec.rb' => 'steno/codec_rfc3339',
  'spec/unit/lib/uaa/uaa_token_decoder_spec.rb' => 'uaa/uaa_token_decoder',
  'spec/unit/lib/cloud_controller/clock/job_timeout_calculator_spec.rb' => 'cloud_controller/clock/job_timeout_calculator',
  'spec/unit/lib/vcap/stats_spec.rb' => 'vcap/stats',
  'spec/unit/lib/services/validation_errors_spec.rb' => 'services/validation_errors',
  'spec/unit/lib/cloud_controller/rack_app_builder_spec.rb' => 'cloud_controller/rack_app_builder',
  'spec/unit/lib/rest_controller/order_applicator_spec.rb' => 'rest_controller/order_applicator',
}

puts "Testing candidates before conversion..."
puts "=" * 80

results = []

CANDIDATES.each do |file|
  next unless File.exist?(file)

  content = File.read(file)
  next unless content.match?(/require ['"]spec_helper['"]/)

  puts "\nTesting: #{file}"

  # Test current version
  system("bundle exec rspec #{file} --format progress > /dev/null 2>&1")
  original_status = $?.success?

  unless original_status
    puts "  ❌ Original test already failing, skipping"
    results << { file: file, status: :skip, reason: 'already failing' }
    next
  end

  # Create backup
  backup_file = "#{file}.bak"
  File.write(backup_file, content)

  # Convert
  new_content = content.gsub(/require ['"]spec_helper['"]/) do
    source_require = REQUIRE_MAP[file]
    if source_require
      "require 'lightweight_spec_helper'\nrequire '#{source_require}'"
    else
      "require 'lightweight_spec_helper'"
    end
  end

  File.write(file, new_content)

  # Test converted version
  system("bundle exec rspec #{file} --format progress > /dev/null 2>&1")
  new_status = $?.success?

  if new_status
    puts "  ✅ Success - converted to lightweight_spec_helper"
    File.delete(backup_file)
    results << { file: file, status: :success }
  else
    puts "  ❌ Failed - reverting"
    File.write(file, content)
    File.delete(backup_file)
    results << { file: file, status: :fail }
  end
end

puts "\n"
puts "=" * 80
puts "SUMMARY"
puts "=" * 80
puts "Success: #{results.count { |r| r[:status] == :success }}"
puts "Failed: #{results.count { |r| r[:status] == :fail }}"
puts "Skipped: #{results.count { |r| r[:status] == :skip }}"

if results.any? { |r| r[:status] == :success }
  puts "\nSuccessfully converted files:"
  results.select { |r| r[:status] == :success }.each do |r|
    puts "  - #{r[:file]}"
  end
end
