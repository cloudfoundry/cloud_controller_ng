module VCAP::CloudController
  class AppStatsPresenter
    def present_json(stats)
      process_stats = []
      stats.each do |info|
        process_stats.concat(ProcessStatsPresenter.new.present_stats_hash(info[:type], info[:stats]))
      end
      process_stats.sort_by! { |i| i[:type] }

      MultiJson.dump({ processes: process_stats }, pretty: true)
    end
  end
end
