require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry/instrumentation/rack'
require 'opentelemetry/instrumentation/http_client'
require 'opentelemetry/instrumentation/net/http'
require 'opentelemetry/instrumentation/mysql2'
require 'opentelemetry/instrumentation/sinatra'
require 'opentelemetry/instrumentation/redis'
require 'opentelemetry/instrumentation/rake'
require 'opentelemetry/instrumentation/delayed_job'
require 'opentelemetry/instrumentation/pg'
require 'opentelemetry/propagator/jaeger'
require 'opentelemetry/propagator/xray'
module CCInitializers
  def self.opentelemetry(cc_config)
    return unless cc_config.dig(:otlp, :tracing, :enabled)

    trace_api_url = cc_config[:otlp][:tracing][:api_url]
    trace_api_token = cc_config[:otlp][:tracing][:api_token]
    sampler = OpenTelemetry::SDK::Trace::Samplers.trace_id_ratio_based(cc_config[:otlp][:tracing][:sampling_ratio])
    sampler = OpenTelemetry::SDK::Trace::Samplers.parent_based(root: sampler) if cc_config.dig(:otlp, :tracing, :propagation, :accept_sampling_instruction)

    OpenTelemetry::SDK.configure do |c|
      c.add_span_processor(
        OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
          OpenTelemetry::Exporter::OTLP::Exporter.new(
            endpoint: trace_api_url,
            headers: {
              Authorization: trace_api_token
            }
          )
        )
      )

      c.resource = OpenTelemetry::SDK::Resources::Resource.create({
                                                                    OpenTelemetry::SemanticConventions::Resource::SERVICE_NAMESPACE => 'cloud_controller_ng',
                                                                    OpenTelemetry::SemanticConventions::Resource::SERVICE_NAME => 'cloud_controller_ng',
                                                                    OpenTelemetry::SemanticConventions::Resource::SERVICE_VERSION => '1.0.1',
                                                                    OpenTelemetry::SemanticConventions::Resource::SERVICE_INSTANCE_ID => Socket.gethostname
                                                                  })

      c.use 'OpenTelemetry::Instrumentation::Rack', {
        record_frontend_span: true
      }
      c.use 'OpenTelemetry::Instrumentation::HttpClient'
      c.use 'OpenTelemetry::Instrumentation::Net::HTTP'
      c.use 'OpenTelemetry::Instrumentation::Mysql2', {
        db_statement: (cc_config[:otlp][:tracing][:redact][:db_statement] ? :obfuscate : :include)
      }
      c.use 'OpenTelemetry::Instrumentation::Sinatra'
      c.use 'OpenTelemetry::Instrumentation::Redis'
      c.use 'OpenTelemetry::Instrumentation::Rake'
      c.use 'OpenTelemetry::Instrumentation::DelayedJob'
      c.use 'OpenTelemetry::Instrumentation::PG', {
        db_statement: (cc_config[:otlp][:tracing][:redact][:db_statement] ? :obfuscate : :include)
      }
    end

    # Configuration of sampling
    OpenTelemetry.tracer_provider.sampler = sampler if trace_api_url && !trace_api_url.empty? && !trace_api_token.empty?

    extractors = define_propagators(cc_config.dig(:otlp, :tracing, :propagation, :extractors))
    injectors = define_propagators(cc_config.dig(:otlp, :tracing, :propagation, :injectors))

    OpenTelemetry.propagation = OpenTelemetry::Context::Propagation::CompositeTextMapPropagator.compose(injectors:, extractors:)
  end

  def self.define_propagators(config_propagators)
    config_propagators = ['none'] if config_propagators.nil?
    config_propagators.uniq.collect do |propagator|
      case propagator
      when 'tracecontext' then OpenTelemetry::Trace::Propagation::TraceContext.text_map_propagator
      when 'baggage' then OpenTelemetry::Baggage::Propagation.text_map_propagator
      when 'b3' then OpenTelemetry::Propagator::B3::Single.text_map_propagator
      when 'b3multi' then OpenTelemetry::Propagator::B3::Multi.text_map_propagator
      when 'jaeger' then OpenTelemetry::Propagator::Jaeger.text_map_propagator
      when 'xray' then OpenTelemetry::Propagator::XRay.text_map_propagator
      when 'none' then OpenTelemetry::SDK::Configurator::NoopTextMapPropagator.new
      else
        OpenTelemetry.logger.warn "The #{propagator} propagator is unknown and cannot be configured"
        OpenTelemetry::SDK::Configurator::NoopTextMapPropagator.new
      end
    end
  end
end
