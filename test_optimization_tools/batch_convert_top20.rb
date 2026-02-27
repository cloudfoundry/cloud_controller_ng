#!/usr/bin/env ruby
# Batch convert top 20 smallest candidates from various directories

CANDIDATES = [
  'spec/unit/models/min_disk_quota_policy_spec.rb',
  'spec/unit/models/max_disk_quota_policy_spec.rb',
  'spec/unit/middleware/new_relic_custom_attributes_spec.rb',
  'spec/unit/jobs/audit_event_job_spec.rb',
  'spec/unit/jobs/space_delete_unmapped_routes_job_spec.rb',
  'spec/unit/models/min_log_rate_limit_policy_spec.rb',
  'spec/unit/middleware/client_ip_spec.rb',
  'spec/unit/jobs/delete_expired_droplet_blob_spec.rb',
  'spec/unit/collection_transformers/username_populator_spec.rb',
  'spec/unit/models/max_private_domains_policy_spec.rb',
  'spec/unit/models/max_routes_policy_spec.rb',
  'spec/unit/jobs/package_bits_spec.rb',
  'spec/unit/presenters/api_presenter_spec.rb',
  'spec/unit/jobs/error_translator_job_spec.rb',
  'spec/unit/middleware/request_metrics_spec.rb',
  'spec/unit/middleware/request_logs_spec.rb',
  'spec/unit/actions/droplet_upload_spec.rb',
  'spec/unit/collection_transformers/router_group_type_populator_spec.rb',
  'spec/unit/jobs/buildpack_delete_spec.rb',
  'spec/unit/jobs/sync_spec.rb',
]

puts "Converting Top 20 Smallest Candidates"
puts "=" * 80

success = []
failed = []

CANDIDATES.each_with_index do |file, idx|
  dir = file.split('/')[2]
  name = File.basename(file)

  print "[#{idx+1}/#{CANDIDATES.count}] [#{dir}] #{name.ljust(45)}... "

  unless File.exist?(file)
    puts "NOT FOUND"
    next
  end

  content = File.read(file)
  unless content.match?(/require ['"]spec_helper['"]/)
    puts "SKIP"
    next
  end

  backup = "#{file}.bak"
  File.write(backup, content)

  # Test original
  system("bundle exec rspec #{file} > /dev/null 2>&1")
  unless $?.success?
    puts "ORIG FAIL"
    File.delete(backup)
    next
  end

  # Convert
  new_content = content.sub(/require ['"]spec_helper['"]/, "require 'lightweight_spec_helper'")
  File.write(file, new_content)

  # Test
  system("bundle exec rspec #{file} > /dev/null 2>&1")
  if $?.success?
    system("bundle exec rubocop #{file} > /dev/null 2>&1")
    if $?.success?
      puts "✅"
      File.delete(backup)
      success << file
    else
      puts "❌ (rubocop)"
      File.write(file, content)
      File.delete(backup)
      failed << file
    end
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
  puts "\n✅ Converted by directory:"
  success.group_by { |f| f.split('/')[2] }.each do |dir, files|
    puts "\n#{dir}: #{files.count} files"
    files.each { |f| puts "  - #{File.basename(f)}" }
  end

  total = 28 + success.count
  puts "\nNew total: #{total} files = #{(total * 6.65).round(1)}s saved"
end
