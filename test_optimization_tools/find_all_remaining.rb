#!/usr/bin/env ruby
# Find all remaining lightweight candidates across spec/unit

EXCLUDE_DIRS = ['lib', 'messages'] # Already heavily optimized

puts "Finding Remaining Lightweight Candidates"
puts "=" * 80

all_candidates = []

Dir.glob('spec/unit/**/*_spec.rb').each do |file|
  # Skip already optimized directories
  next if EXCLUDE_DIRS.any? { |dir| file.include?("spec/unit/#{dir}/") }

  content = File.read(file)
  next unless content.match?(/require ['"]spec_helper['"]/)

  # Skip if has heavy dependencies
  next if content.match?(/\.make\(|\.create\(|\.build\(/)
  next if content.match?(/TestConfig/)
  next if content.match?(/VCAP::CloudController::Models/)
  next if content.match?(/before.*:all.*do/)

  lines = File.readlines(file).count
  next if lines >= 150

  # Must have doubles/stubs
  next unless content.match?(/double\(|instance_double\(|allow\(|stub|receive/)

  dir = file.split('/')[2]
  all_candidates << { file: file, lines: lines, dir: dir }
end

all_candidates.sort_by! { |c| c[:lines] }

puts "\nFound #{all_candidates.count} candidates"
puts "\nBy directory:"
all_candidates.group_by { |c| c[:dir] }.each do |dir, files|
  puts "  #{dir}: #{files.count}"
end

puts "\nTop 20 smallest:"
all_candidates.first(20).each_with_index do |c, i|
  name = File.basename(c[:file])
  puts "#{(i+1).to_s.rjust(3)}. [#{c[:lines].to_s.rjust(4)} lines] [#{c[:dir]}] #{name}"
end

# Also check lib and messages for any we might have missed
puts "\n" + "=" * 80
puts "Double-checking lib and messages for missed candidates..."

missed = []
['spec/unit/lib', 'spec/unit/messages'].each do |dir|
  Dir.glob("#{dir}/**/*_spec.rb").each do |file|
    content = File.read(file)
    next unless content.match?(/require ['"]spec_helper['"]/)

    next if content.match?(/\.make\(|\.create\(|\.build\(|TestConfig|VCAP::CloudController::Models|before.*:all.*do/)

    lines = File.readlines(file).count
    next if lines >= 150
    next unless content.match?(/double\(|instance_double\(|allow\(|stub|receive/)

    missed << { file: file, lines: lines }
  end
end

if missed.any?
  puts "\nFound #{missed.count} missed candidates in lib/messages:"
  missed.sort_by { |c| c[:lines] }.first(10).each do |c|
    puts "  - #{File.basename(c[:file])} (#{c[:lines]} lines)"
  end
end

puts "\n" + "=" * 80
puts "Total new opportunities: #{all_candidates.count + missed.count}"
