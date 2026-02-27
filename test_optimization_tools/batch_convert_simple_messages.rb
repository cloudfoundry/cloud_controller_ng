#!/usr/bin/env ruby
# Batch convert simple message specs to lightweight_spec_helper

require 'fileutils'

files_to_convert = [
  'spec/unit/messages/shared_spaces_show_message_spec.rb',
  'spec/unit/messages/process_show_message_spec.rb',
  'spec/unit/messages/service_instance_show_message_spec.rb',
  'spec/unit/messages/space_show_message_spec.rb',
  'spec/unit/messages/app_show_message_spec.rb',
  'spec/unit/messages/role_show_message_spec.rb',
  'spec/unit/messages/route_show_message_spec.rb',
  'spec/unit/messages/route_destination_update_message_spec.rb'
]

def convert_file(file_path)
  return unless File.exist?(file_path)

  content = File.read(file_path)

  # Skip if already converted
  return if content.include?('lightweight_spec_helper')

  # Find the message file name from the require statement
  message_require = content[/require 'messages\/(.+)'/, 1]
  return unless message_require

  # Replace spec_helper with lightweight_spec_helper and add explicit require
  new_content = content.sub(
    "require 'spec_helper'\nrequire 'messages/#{message_require}'",
    "require 'lightweight_spec_helper'\nrequire 'messages/#{message_require}'"
  )

  File.write(file_path, new_content)
  puts "✓ Converted: #{file_path}"
  file_path
rescue => e
  puts "✗ Failed: #{file_path} - #{e.message}"
  nil
end

converted = []
files_to_convert.each do |file|
  result = convert_file(file)
  converted << file if result
end

puts "\n#{converted.length} files converted"
puts converted
