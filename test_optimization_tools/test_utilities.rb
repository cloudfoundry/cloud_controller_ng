#!/usr/bin/env ruby
# Test small utility/generator files

CANDIDATES = [
  'spec/unit/lib/cloud_controller/random_route_generator_spec.rb',
  'spec/unit/lib/cloud_controller/blobstore/blob_key_generator_spec.rb',
  'spec/unit/lib/cloud_controller/diego/lifecycle_bundle_uri_generator_spec.rb',
  'spec/unit/lib/cloud_controller/diego/staging_action_builder_spec.rb',
  'spec/unit/lib/cloud_controller/diego/task_completion_callback_generator_spec.rb',
  'spec/unit/lib/cloud_controller/blobstore/url_generator/upload_url_generator_spec.rb',
  'spec/unit/lib/cloud_controller/port_generator_spec.rb',
  'spec/unit/lib/http_response_error_spec.rb',
  'spec/unit/lib/http_request_error_spec.rb',
]

puts "Testing Small Utility/Generator Files"
puts "=" * 80

success = []
failed = []

CANDIDATES.each_with_index do |file, idx|
  print "[#{idx+1}/#{CANDIDATES.count}] #{file.split('/').last.ljust(50)}... "

  unless File.exist?(file)
    puts "SKIP"
    next
  end

  content = File.read(file)
  unless content.match?(/require ['"]spec_helper['"]/)
    puts "SKIP"
    next
  end

  # Test original
  system("bundle exec rspec #{file} > /dev/null 2>&1")
  unless $?.success?
    puts "ORIG FAIL"
    next
  end

  # Try conversion
  backup = "#{file}.bak"
  File.write(backup, content)

  new_content = content.sub(/require ['"]spec_helper['"]/, "require 'lightweight_spec_helper'")
  File.write(file, new_content)

  system("bundle exec rspec #{file} > /dev/null 2>&1")

  if $?.success?
    puts "✅"
    File.delete(backup)
    success << file
  else
    puts "❌"
    File.write(file, content)
    File.delete(backup)
    failed << file
  end
end

puts "\n" + "=" * 80
puts "✅ Success: #{success.count}"
puts "❌ Failed:  #{failed.count}"

if success.any?
  puts "\n✅ Successfully converted:"
  success.each { |f| puts "  - #{f.split('/').last}" }
  puts "\nNew total: #{(15 + success.count)} files = #{((15 + success.count) * 6.65).round(1)}s saved per run"
end
