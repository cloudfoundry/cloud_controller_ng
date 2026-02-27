#!/usr/bin/env ruby
# Analyze other spec/unit directories for lightweight candidates

DIRECTORIES = [
  'spec/unit/actions',
  'spec/unit/messages',
  'spec/unit/decorators',
  'spec/unit/fetchers',
  'spec/unit/presenters',
]

puts "Analyzing Other spec/unit Directories"
puts "=" * 80

DIRECTORIES.each do |dir|
  next unless Dir.exist?(dir)

  puts "\n#{dir}/"
  puts "-" * 80

  spec_files = Dir.glob("#{dir}/**/*_spec.rb")
  spec_helper_files = spec_files.select { |f| File.read(f).match?(/require ['"]spec_helper['"]/) }
  lightweight_files = spec_files.select { |f| File.read(f).match?(/require ['"]lightweight_spec_helper['"]/) }

  puts "Total specs: #{spec_files.count}"
  puts "Using spec_helper: #{spec_helper_files.count}"
  puts "Using lightweight: #{lightweight_files.count}"

  # Analyze for good candidates
  candidates = []

  spec_helper_files.each do |file|
    content = File.read(file)

    # Skip files with heavy dependencies
    next if content.match?(/\.make\(|\.create\(|\.build\(/)
    next if content.match?(/TestConfig/)
    next if content.match?(/VCAP::CloudController::Models/)
    next if content.match?(/before.*:all.*do/)

    # Look for simple tests
    lines = File.readlines(file).count
    uses_doubles = content.match?(/double\(|instance_double\(/)
    uses_stubs = content.match?(/allow\(|stub|receive/)

    if lines < 150 && (uses_doubles || uses_stubs)
      candidates << { file: file, lines: lines }
    end
  end

  if candidates.any?
    puts "Potential candidates: #{candidates.count}"
    candidates.sort_by! { |c| c[:lines] }
    puts "\nTop 10 smallest:"
    candidates.first(10).each_with_index do |c, i|
      name = c[:file].split('/').last
      puts "  #{(i+1).to_s.rjust(2)}. [#{c[:lines].to_s.rjust(4)} lines] #{name}"
    end
  else
    puts "No obvious candidates found"
  end
end

puts "\n" + "=" * 80
puts "Summary by directory:"
puts "=" * 80

total_candidates = 0
DIRECTORIES.each do |dir|
  next unless Dir.exist?(dir)

  spec_files = Dir.glob("#{dir}/**/*_spec.rb")
  spec_helper_files = spec_files.select { |f| File.read(f).match?(/require ['"]spec_helper['"]/) }

  candidates = spec_helper_files.select do |file|
    content = File.read(file)
    !content.match?(/\.make\(|\.create\(|\.build\(|TestConfig|VCAP::CloudController::Models|before.*:all.*do/) &&
    File.readlines(file).count < 150 &&
    content.match?(/double\(|instance_double\(|allow\(|stub|receive/)
  end

  total_candidates += candidates.count
  puts "#{dir.ljust(30)} #{candidates.count} candidates"
end

puts "\nTotal potential candidates: #{total_candidates}"
