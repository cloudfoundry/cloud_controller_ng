# rubocop:disable Metrics/BlockLength
namespace :gem_freshness do
  desc 'Generate a report of gem freshness'
  task report: :environment do
    require 'bundler'
    require 'net/http'
    require 'oj'
    require 'date'
    require 'rubygems/version'

    GEMFILE = ENV.fetch('GEMFILE', 'Gemfile')
    LOCKFILE = ENV.fetch('LOCKFILE', 'Gemfile.lock')

    def http_get_json(url)
      uri = URI(url)
      res = Net::HTTP.get_response(uri)
      return nil unless res.is_a?(Net::HTTPSuccess)

      Oj.load(res.body)
    rescue StandardError
      nil
    end

    def rubygems_latest_info(name)
      http_get_json("https://rubygems.org/api/v1/gems/#{name}.json")
    end

    def rubygems_versions(name)
      http_get_json("https://rubygems.org/api/v1/versions/#{name}.json")
    end

    def parse_date(date)
      return nil if date.nil? || date.to_s.empty?

      DateTime.parse(date).to_date
    rescue StandardError
      nil
    end

    def fmt_date(date)
      date ? date.strftime('%Y-%m-%d') : '-'
    end

    unless File.exist?(GEMFILE) && File.exist?(LOCKFILE)
      warn "Missing #{GEMFILE} or #{LOCKFILE} in current directory."
      exit 1
    end

    definition = Bundler::Definition.build(GEMFILE, LOCKFILE, nil)
    direct_names = definition.dependencies.to_set(&:name)

    lock = Bundler::LockfileParser.new(Bundler.read_file(LOCKFILE))
    locked_specs = lock.specs.sort_by(&:name)

    rows = []
    total = 0
    outdated = 0
    no_ruby_gems_data = 0

    locked_specs.each do |spec|
      name = spec.name
      current_v = Gem::Version.new(spec.version.to_s)

      latest_info = rubygems_latest_info(name)
      versions = rubygems_versions(name)

      total += 1

      if latest_info.nil? || versions.nil?
        no_ruby_gems_data += 1
        rows << {
          type: direct_names.include?(name) ? 'direct' : 'transitive',
          name: name,
          current: current_v.to_s,
          current_date: nil,
          latest: nil,
          latest_date: nil,
          status: 'Could not fetch RubyGems data'
        }
        next
      end

      latest_v_str = latest_info['version']
      latest_v = latest_v_str ? Gem::Version.new(latest_v_str) : nil

      # versions endpoint returns array like:
      # [{"number":"x.y.z","created_at":"...","prerelease":false,...}, ...]
      by_number = {}
      versions.each do |v|
        num = v['number']
        by_number[num] = parse_date(v['created_at']) if num
      end

      current_date = by_number[current_v.to_s]
      latest_date = parse_date(latest_info['version_created_at']) || (latest_v ? by_number[latest_v.to_s] : nil)

      status =
        if latest_v && latest_v > current_v
          outdated += 1
          'OUTDATED'
        else
          'ok'
        end

      rows << {
        type: direct_names.include?(name) ? 'direct' : 'transitive',
        name: name,
        current: current_v.to_s,
        current_date: current_date,
        latest: latest_v&.to_s,
        latest_date: latest_date,
        status: status
      }
    end

    # Markdown output
    puts '# Ruby dependencies report'
    puts
    puts "- Generated: `#{Time.now.utc.strftime('%Y-%m-%d %H:%M:%S UTC')}`"
    puts "- Gemfile: `#{GEMFILE}`"
    puts "- Lockfile: `#{LOCKFILE}`"
    puts

    puts '| Type | Gem | Current | Current released | Latest | Latest released | Status |'
    puts '|---|---|---:|---:|---:|---:|---|'

    rows.each do |r|
      current_date = fmt_date(r[:current_date])
      latest_date = fmt_date(r[:latest_date])
      puts "| #{r[:type]} | `#{r[:name]}` | `#{r[:current]}` | #{current_date} | #{r[:latest] ? "`#{r[:latest]}`" : '-'} | #{latest_date} | #{r[:status]} |"
    end

    puts
    puts '## Summary'
    puts
    puts "- Total gems: **#{total}**"
    puts "- Outdated: **#{outdated}**"
    puts "- No RubyGems API data: **#{no_ruby_gems_data}**"
    puts
  end
end
# rubocop:enable Metrics/BlockLength
