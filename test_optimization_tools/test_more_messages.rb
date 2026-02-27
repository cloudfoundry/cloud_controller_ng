#!/usr/bin/env ruby
# Test remaining message specs

CANDIDATES = [
  'spec/unit/messages/stacks_list_message_spec.rb',
  'spec/unit/messages/orgs_list_message_spec.rb',
  'spec/unit/messages/buildpacks_list_message_spec.rb',
  'spec/unit/messages/deployments_list_message_spec.rb',
  'spec/unit/messages/app_revisions_list_message_spec.rb',
  'spec/unit/messages/service_instances_list_message_spec.rb',
  'spec/unit/messages/builds_list_message_spec.rb',
  'spec/unit/messages/isolation_segments_list_message_spec.rb',
]

puts "Testing More Message Specs"
puts "=" * 80

success = []
failed = []

CANDIDATES.each_with_index do |file, idx|
  name = file.split('/').last

  print "[#{idx+1}/#{CANDIDATES.count}] #{name.ljust(50)}... "

  unless File.exist?(file)
    puts "NOT FOUND"
    next
  end

  content = File.read(file)
  unless content.match?(/require ['"]spec_helper['"]/)
    puts "SKIP"
    next
  end

  # Backup and test original
  backup = "#{file}.bak"
  File.write(backup, content)

  system("bundle exec rspec #{file} > /dev/null 2>&1")
  unless $?.success?
    puts "ORIG FAIL"
    File.delete(backup)
    next
  end

  # Convert
  new_content = content.sub(/require ['"]spec_helper['"]/, "require 'lightweight_spec_helper'")
  File.write(file, new_content)

  # Test and check RuboCop
  system("bundle exec rspec #{file} > /dev/null 2>&1")
  test_pass = $?.success?

  if test_pass
    system("bundle exec rubocop #{file} > /dev/null 2>&1")
    rubocop_pass = $?.success?
  end

  if test_pass && rubocop_pass
    puts "✅"
    File.delete(backup)
    success << file
  else
    result = !test_pass ? "test fail" : "rubocop fail"
    puts "❌ (#{result})"
    File.write(file, content)
    File.delete(backup)
    failed << file
  end
end

puts "\n" + "=" * 80
puts "✅ Success: #{success.count}"
puts "❌ Failed:  #{failed.count}"

if success.any?
  puts "\n✅ Converted:"
  success.each { |f| puts "  - #{f.split('/').last}" }

  total = 17 + success.count
  puts "\nNew total: #{total} files = #{(total * 6.65).round(1)}s saved"
end
