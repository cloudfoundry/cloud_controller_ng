#!/usr/bin/env ruby
# Analyze spec/unit/lib directory for lightweight conversion candidates

require 'fileutils'

puts "Analyzing spec/unit/lib for lightweight_spec_helper candidates"
puts "=" * 80

spec_files = Dir.glob('spec/unit/lib/**/*_spec.rb')

# Filter to only spec_helper users
spec_helper_files = spec_files.select { |f| File.read(f).match?(/require ['"]spec_helper['"]/) }

puts "\nTotal lib spec files: #{spec_files.count}"
puts "Using spec_helper: #{spec_helper_files.count}"
puts "Already using lightweight: #{spec_files.count - spec_helper_files.count}"

# Analyze each file
candidates = []

spec_helper_files.each do |file|
  content = File.read(file)

  # Skip files that use heavy features
  next if content.match?(/\.make\(|\.create\(|\.build\(/)  # Factory usage
  next if content.match?(/TestConfig/)                      # Config system
  next if content.match?(/type: :controller|type: :api/)    # Controller tests
  next if content.match?(/Sequel::Model\.db|Database\.connection/) # Direct DB access
  next if content.match?(/VCAP::CloudController::Models::/)  # Model namespace (likely needs DB)

  # Good indicators for lightweight
  uses_doubles = content.match?(/double\(|instance_double\(|class_double\(/)
  uses_stubs = content.match?(/allow\(|stub|receive/)
  minimal_setup = !content.match?(/before.*:all/)
  no_integration = !content.match?(/IntegrationHelper|RequestHelper/)

  # Count as candidate if it seems pure
  if (uses_doubles || uses_stubs) && minimal_setup && no_integration
    lines = File.readlines(file).count
    candidates << { file: file, lines: lines, uses_doubles: uses_doubles }
  end
end

puts "\n" + "=" * 80
puts "FOUND #{candidates.count} STRONG CANDIDATES"
puts "=" * 80

# Sort by file size (smaller = easier to verify)
candidates.sort_by! { |c| c[:lines] }

puts "\nTop 30 candidates (sorted by size, smallest first):"
candidates.first(30).each_with_index do |c, i|
  file_short = c[:file].gsub('spec/unit/lib/', '')
  puts "#{(i+1).to_s.rjust(3)}. [#{c[:lines].to_s.rjust(4)} lines] #{file_short}"
end

# Sample a few to show content
puts "\n" + "=" * 80
puts "SAMPLE ANALYSIS (first 3 candidates)"
puts "=" * 80

candidates.first(3).each do |c|
  puts "\n#{c[:file].gsub('spec/unit/lib/', '')}:"
  content = File.read(c[:file])

  # Check what it's testing
  if content =~ /RSpec\.describe\s+([^\s]+)/
    puts "  Tests: #{$1}"
  end

  # Check for potential dependencies
  requires = content.scan(/^require ['"]([^'"]+)['"]/).flatten
  puts "  Requires: #{requires.join(', ')}" if requires.any?

  # Check for describe blocks
  describes = content.scan(/^\s*describe ['"]([^'"]+)['"]/).flatten
  puts "  Describes: #{describes.first(3).join(', ')}..." if describes.any?
end

puts "\n" + "=" * 80
puts "RECOMMENDATION"
puts "=" * 80
puts "
Start with the smallest files (< 100 lines) as they're easiest to verify.
Use the existing optimize_specs.rb script but update the CANDIDATES array
with these file paths.

Estimated time savings if all #{candidates.count} files are converted:
  #{candidates.count} files × 6.65 seconds = #{(candidates.count * 6.65).round(1)} seconds per run
"
