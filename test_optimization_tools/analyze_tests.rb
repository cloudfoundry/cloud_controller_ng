#!/usr/bin/env ruby
# Script to analyze spec files and suggest optimization opportunities

require 'fileutils'

puts "Test Optimization Analyzer"
puts "=" * 80

# Find all spec files
spec_files = Dir.glob('spec/unit/**/*_spec.rb')

puts "\n1. SPEC HELPER USAGE ANALYSIS"
puts "-" * 80

spec_helper_files = spec_files.select { |f| File.read(f).match?(/require ['"]spec_helper['"]/) }
lightweight_files = spec_files.select { |f| File.read(f).match?(/require ['"]lightweight_spec_helper['"]/) }
db_helper_files = spec_files.select { |f| File.read(f).match?(/require ['"]db_spec_helper['"]/) }

puts "Total spec files: #{spec_files.count}"
puts "Using spec_helper: #{spec_helper_files.count} (#{(spec_helper_files.count.to_f / spec_files.count * 100).round(1)}%)"
puts "Using lightweight_spec_helper: #{lightweight_files.count} (#{(lightweight_files.count.to_f / spec_files.count * 100).round(1)}%)"
puts "Using db_spec_helper: #{db_helper_files.count} (#{(db_helper_files.count.to_f / spec_files.count * 100).round(1)}%)"

puts "\n2. POTENTIAL LIGHTWEIGHT CANDIDATES"
puts "-" * 80
puts "Looking for spec_helper files with no factory usage...\n"

candidates = []
spec_helper_files.sample(50).each do |file|
  content = File.read(file)

  # Skip if it uses factories, TestConfig, or database operations
  next if content.match?(/\.make\(|\.create\(|\.build\(/)
  next if content.match?(/TestConfig/)
  next if content.match?(/VCAP::CloudController::/)
  next if content.match?(/type: :controller|type: :api|type: :integration/)

  # Good candidates: pure logic, only doubles/stubs
  if content.match?(/double\(|allow\(|stub|receive/) &&
     !content.match?(/Database|Sequel::Model|ActiveRecord/)
    candidates << file
  end
end

puts "Found #{candidates.count} potential candidates (from random sample of 50):"
candidates.first(15).each do |file|
  puts "  - #{file.gsub(Dir.pwd + '/', '')}"
end

puts "\n3. SLOWEST SPEC FILES BY SIZE"
puts "-" * 80

large_specs = spec_files.map { |f| [f, File.readlines(f).count] }
                        .sort_by { |_, lines| -lines }
                        .first(10)

puts "Top 10 largest spec files (may contain duplication):"
large_specs.each do |file, lines|
  puts "  #{lines.to_s.rjust(5)} lines - #{file.gsub(Dir.pwd + '/', '')}"
end

puts "\n4. BEFORE(:ALL) USAGE"
puts "-" * 80

before_all_files = spec_files.select { |f| File.read(f).match?(/before.*:all/) }
puts "Files using before(:all): #{before_all_files.count}"
puts "These may have expensive setup that could be optimized:"
before_all_files.first(10).each do |file|
  content = File.read(file)
  count = content.scan(/before.*:all/).count
  puts "  #{count}x - #{file.gsub(Dir.pwd + '/', '')}"
end

puts "\n5. FACTORY USAGE DENSITY"
puts "-" * 80

factory_heavy = spec_files.map do |f|
  content = File.read(f)
  factory_calls = content.scan(/\.make\(|\.create\(|\.build\(/).count
  [f, factory_calls, File.readlines(f).count]
end.select { |_, calls, _| calls > 20 }
   .sort_by { |_, calls, lines| -(calls.to_f / lines) }
   .first(10)

puts "Top 10 files with highest factory usage density:"
factory_heavy.each do |file, calls, lines|
  density = (calls.to_f / lines * 100).round(1)
  puts "  #{calls.to_s.rjust(4)} factories / #{lines.to_s.rjust(4)} lines (#{density.to_s.rjust(4)}%) - #{file.gsub(Dir.pwd + '/', '').split('/').last}"
end

puts "\n6. RECOMMENDATION SUMMARY"
puts "=" * 80
puts "
High Priority:
1. Convert #{candidates.count * 2} more files to lightweight_spec_helper (est. 5-10 min savings)
2. Review #{before_all_files.count} files with before(:all) for optimization
3. Audit #{factory_heavy.count} files with heavy factory usage

Medium Priority:
4. Split #{large_specs.first(3).count} largest test files for better parallelization
5. Look for duplicate tests in controller specs

Low Priority:
6. Consider test tagging strategy for slow tests
7. Profile integration tests separately
"

puts "Generated: #{Time.now}"
puts "=" * 80
