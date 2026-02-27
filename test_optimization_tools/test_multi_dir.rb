#!/usr/bin/env ruby
# Test conversion of smallest candidates from each directory

CANDIDATES = [
  # presenters (smallest)
  'spec/unit/presenters/api_presenter_spec.rb',
  'spec/unit/presenters/service_key_presenter_spec.rb',
  'spec/unit/presenters/base_presenter_spec.rb',

  # actions
  'spec/unit/actions/droplet_upload_spec.rb',
  'spec/unit/actions/buildpack_upload_spec.rb',

  # messages
  'spec/unit/messages/domains_list_message_spec.rb',
  'spec/unit/messages/spaces_list_message_spec.rb',

  # decorators
  'spec/unit/decorators/embed_process_instances_decorator_spec.rb',
]

puts "Testing Candidates from Multiple Directories"
puts "=" * 80

success = []
failed = []

CANDIDATES.each_with_index do |file, idx|
  dir = file.split('/')[2]
  name = file.split('/').last

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

  # Backup
  backup = "#{file}.bak"
  File.write(backup, content)

  # Test original first
  system("bundle exec rspec #{file} > /dev/null 2>&1")
  unless $?.success?
    puts "ORIG FAIL"
    File.delete(backup)
    next
  end

  # Try simple conversion
  new_content = content.sub(/require ['"]spec_helper['"]/, "require 'lightweight_spec_helper'")
  File.write(file, new_content)

  # Test converted
  system("bundle exec rspec #{file} > /dev/null 2>&1")
  if $?.success?
    # Also run RuboCop
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
puts "Results:"
puts "  ✅ Success: #{success.count}"
puts "  ❌ Failed:  #{failed.count}"

if success.any?
  puts "\n✅ Successfully converted:"
  success.each do |f|
    dir = f.split('/')[2]
    name = f.split('/').last
    puts "  [#{dir}] #{name}"
  end

  total = 15 + success.count
  savings = total * 6.65
  puts "\nNew totals:"
  puts "  Files converted: #{total}"
  puts "  Time saved: #{savings.round(1)}s per run"
end

if failed.any?
  puts "\n❌ Failed conversions:"
  failed.first(5).each do |f|
    puts "  - #{f.split('/').last}"
  end
end
