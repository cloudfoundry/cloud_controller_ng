#!/usr/bin/env ruby
# Test smallest presenter specs

CANDIDATES = [
  'spec/unit/presenters/v3/space_ssh_feature_presenter_spec.rb',
  'spec/unit/presenters/v2/service_instance_shared_from_presenter_spec.rb',
  'spec/unit/presenters/v3/organization_usage_summary_presenter_spec.rb',
  'spec/unit/presenters/v2/service_instance_shared_to_presenter_spec.rb',
  'spec/unit/presenters/api/space_presenter_spec.rb',
  'spec/unit/presenters/api_url_builder_spec.rb',
  'spec/unit/presenters/api/user_presenter_spec.rb',
  'spec/unit/presenters/v3/info_usage_summary_presenter_spec.rb',
  'spec/unit/presenters/v3/cache_key_presenter_spec.rb',
  'spec/unit/presenters/v3/environment_variable_group_presenter_spec.rb',
]

puts "Testing Presenter Specs"
puts "=" * 80

success = []
failed = []

CANDIDATES.each_with_index do |file, idx|
  name = file.split('/').last

  print "[#{idx+1}/#{CANDIDATES.count}] #{name.ljust(55)}... "

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
  puts "\n✅ Converted:"
  success.each { |f| puts "  - #{f.split('/').last}" }

  total = 20 + success.count
  puts "\nNew total: #{total} files = #{(total * 6.65).round(1)}s saved"
end
