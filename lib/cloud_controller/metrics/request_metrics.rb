require 'vcap/component'
require 'statsd'

module VCAP::CloudController
  module Metrics
    class RequestMetrics
      def initialize(statsd=Statsd.new)
        @statsd = statsd
        init_varz
      end

      def start_request
        VCAP::Component.varz.synchronize do
          VCAP::Component.varz[:vcap_sinatra][:requests][:outstanding] += 1
        end

        @statsd.increment 'cc.requests.outstanding'
      end

      def complete_request(status)
        VCAP::Component.varz.synchronize do
          VCAP::Component.varz[:vcap_sinatra][:requests][:outstanding] -= 1
          VCAP::Component.varz[:vcap_sinatra][:requests][:completed] += 1
          VCAP::Component.varz[:vcap_sinatra][:http_status][status] += 1
        end

        @statsd.batch do |batch|
          batch.decrement 'cc.requests.outstanding'
          batch.increment 'cc.requests.completed'
          batch.increment "cc.http_status.#{status.to_s[0]}XX"
        end
      end

      private

      def init_varz
        http_status = {}
        [(100..101), (200..206), (300..307), (400..422), (500..505)].each do |r|
          r.each { |c| http_status[c] = 0 }
        end

        vcap_sinatra = {
          requests:    { outstanding: 0, completed: 0 },
          http_status: http_status,
        }

        VCAP::Component.varz.synchronize do
          VCAP::Component.varz[:vcap_sinatra] ||= {}
          VCAP::Component.varz[:vcap_sinatra].merge!(vcap_sinatra)
        end
      end
    end
  end
end
