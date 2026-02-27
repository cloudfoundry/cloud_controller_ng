#!/usr/bin/env ruby
# Test very small message specs (< 50 lines)

CANDIDATES = [
  'spec/unit/messages/shared_spaces_show_message_spec.rb',
  'spec/unit/messages/process_show_message_spec.rb',
  'spec/unit/messages/service_instance_show_message_spec.rb',
  'spec/unit/messages/user_update_message_spec.rb',
  'spec/unit/messages/security_group_apply_message_spec.rb',
  'spec/unit/messages/space_quota_apply_message_spec.rb',
  'spec/unit/messages/space_show_message_spec.rb',
  'spec/unit/messages/app_show_message_spec.rb',
  'spec/unit/messages/role_show_message_spec.rb',
  'spec/unit/messages/domain_show_message_spec.rb',
  'spec/unit/messages/domain_update_message_spec.rb',
  'spec/unit/messages/domain_delete_shared_org_message_spec.rb',
  'spec/unit/messages/authentication_message_mixin_spec.rb',
  'spec/unit/messages/metadata_list_message_spec.rb',
  'spec/unit/messages/package_update_message_spec.rb',
]

puts "Testing Small Message Specs"
puts "=" * 80

success = []
failed = []

CANDIDATES.each_with_index do |file, idx|
  name = file.split('/').last

  print "[#{idx+1}/#{CANDIDATES.count}] #{name.ljust(52)}... "

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
    # Check RuboCop
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
  puts "\n✅ Converted:"
  success.each { |f| puts "  - #{f.split('/').last}" }

  total = 20 + success.count
  puts "\nNew total: #{total} files = #{(total * 6.65).round(1)}s saved"
end

if failed.any?
  puts "\n❌ Failed:"
  failed.first(5).each { |f| puts "  - #{f.split('/').last}" }
end
