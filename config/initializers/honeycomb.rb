require 'honeycomb-beeline'

module CCInitializers
  def self.honeycomb(cc_config)
    if cc_config[:honeycomb]
      Honeycomb.configure do |hc|
        hc.write_key = cc_config[:honeycomb][:write_key]
        hc.dataset = cc_config[:honeycomb][:dataset]
        hc.sample_hook do |fields|
          CustomSampler.sample(fields)
        end
      end
    end
  end
end

class CustomSampler
  extend Honeycomb::DeterministicSampler
  def self.sample(fields)
    sample_rate = 1
    # Remove this if you want a closer look at our DB calls
    if fields['meta.package'] == 'sequel'
      return [false, 0]
    end

    # These calls will dominate the dataset if you don't filter them
    if fields['request.path'] == '/healthz' && fields['response.status_code'] == 200
      return [false, 0]
    end

    if should_sample(sample_rate, fields['trace.trace_id'])
      return [true, sample_rate]
    end

    return [false, 0]
  end
end
