#!/usr/bin/env ruby
# Find truly simple standalone tests - no models, no config, just pure logic

require 'fileutils'

puts "Finding Truly Standalone Tests"
puts "=" * 80

spec_files = Dir.glob('spec/unit/lib/**/*_spec.rb')
spec_helper_files = spec_files.select { |f| File.read(f).match?(/require ['"]spec_helper['"]/) }

candidates = []

spec_helper_files.each do |file|
  content = File.read(file)

  # Hard excludes - these definitely need spec_helper
  next if content.match?(/\.make\(|\.create\(|\.build\(/)  # Factory usage
  next if content.match?(/TestConfig/)                      # Config
  next if content.match?(/VCAP::CloudController::Models/)    # Models
  next if content.match?(/VCAP::CloudController::Config/)    # Config
  next if content.match?(/type: :/)                         # Tagged test types
  next if content.match?(/DatabaseCleaner/)                 # Database
  next if content.match?(/Sequel::Model\.db/)               # Direct DB
  next if content.match?(/before.*:all.*do/)                # Setup blocks (often expensive)

  # Look for good indicators
  has_rspec_describe = content.match?(/RSpec\.describe/)
  uses_doubles = content.match?(/double\(|instance_double\(/)
  uses_stubs = content.match?(/allow\(|stub|receive/)
  simple_expects = content.match?(/expect\(/)
  small_file = File.readlines(file).count < 150

  # Only pure logic tests
  if has_rspec_describe && (uses_doubles || uses_stubs || simple_expects) && small_file
    # Check for describe blocks to understand what's tested
    describes = content.scan(/RSpec\.describe\s+([^\s{]+)/).flatten

    candidates << {
      file: file,
      lines: File.readlines(file).count,
      describes: describes,
      uses_doubles: uses_doubles,
      uses_stubs: uses_stubs
    }
  end
end

# Sort by simplicity (fewest lines)
candidates.sort_by! { |c| c[:lines] }

puts "\nFound #{candidates.count} potentially simple candidates"
puts "\nTop 40 (sorted by size):"
puts "-" * 80

candidates.first(40).each_with_index do |c, i|
  file_short = c[:file].gsub('spec/unit/lib/', '')
  describes = c[:describes].first || '?'
  puts "#{(i+1).to_s.rjust(3)}. [#{c[:lines].to_s.rjust(4)} lines] #{describes.ljust(50)} #{file_short}"
end

puts "\n" + "=" * 80
puts "Recommended approach: Test these in small batches (5-10 at a time)"
puts "=" * 80

# Output a small test batch
puts "\nTest batch (10 smallest):"
candidates.first(10).each do |c|
  puts "  '#{c[:file]}',"
end
