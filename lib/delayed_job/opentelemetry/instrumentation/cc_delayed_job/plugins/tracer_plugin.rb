# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'delayed/plugin'

module OpenTelemetry
  module Instrumentation
    module CCDelayedJob
      module Plugins
        # Delayed Job plugin that instruments invoke_job and other hooks
        class TracerPlugin < Delayed::Plugin
          class << self
            def instrument_enqueue(job)
              return yield(job) unless enabled?

              job_payload = job.payload_object

              attributes = build_attributes(job)
              attributes['messaging.operation'] = 'publish'
              attributes.compact!

              # Inject a new context into the job payload for linking this span to the job span
              links = []
              if job_payload.respond_to?(:otel_job_trace_carrier=)
                job_span = Trace::Span.new(span_context: Trace::SpanContext.new(trace_flags: current_span_context.trace_flags))
                Context.with_current(Trace.context_with_span(job_span)) do
                  job_payload.otel_job_trace_carrier = {}.tap { |carrier| propagator.inject(carrier) }
                end
                links = [Trace::Link.new(job_span.context, attributes:)]
              end

              tracer.in_span("DelayedJobQueue #{job_queue(job)}: #{job_name(job)} enqueue", attributes: attributes, kind: :producer, links: links) do |span|
                # Inject the current context into the job payload for linking the job to this span
                job_payload.otel_api_trace_carrier = {}.tap { |carrier| propagator.inject(carrier) } if job_payload.respond_to?(:otel_api_trace_carrier=)

                # Persist changes in the job payload
                job.payload_object = job_payload

                yield job
                span.set_attribute('messaging.message_id', job.id.to_s)
                add_events(span, job)
              end
            end

            def instrument_invoke(job)
              return yield(job) unless enabled?

              # Add attributes to the span
              attributes = build_attributes(job)
              attributes['messaging.delayed_job.attempts'] = job.attempts if job.attempts
              attributes['messaging.delayed_job.locked_by'] = job.locked_by if job.locked_by
              attributes['messaging.operation'] = 'process'
              attributes['messaging.message_id'] = job.id.to_s
              attributes.compact!

              # Extract the apis context from the job payload to link this job to the api span
              api_context = Context.new({})
              api_context = propagator.extract(job.payload_object.otel_api_trace_carrier) if job.payload_object.respond_to?(:otel_api_trace_carrier)

              # Extract the jobs context from the job payload to use it since it was already linked by the span of the api
              job_context = Context.new({})
              job_context = propagator.extract(job.payload_object.otel_job_trace_carrier) if job.payload_object.respond_to?(:otel_job_trace_carrier)

              # Set a link to the api span if it exists
              api_span_context = current_span_context(context: api_context)
              links = api_span_context.valid? ? [Trace::Link.new(api_span_context, attributes:)] : []

              # Reuse the producer has propagator to the consumer, in case of a invalid job span or a retried job we create a new context
              Context.with_current(job_context) do
                job_root_span = start_predefined_root_span(job, links: links, attributes: attributes, kind: :consumer)
                Trace.with_span(job_root_span) do |span|
                  # Set the logger to include the propagated trace context values for compatibility with the zipkin middleware
                  if OpenTelemetry::Trace.current_span.context.valid?
                    Steno.config.context.data['otel_trace_id'] = OpenTelemetry::Trace.current_span.context.trace_id.unpack1('H*')
                    Steno.config.context.data['otel_span_id'] = OpenTelemetry::Trace.current_span.context.span_id.unpack1('H*')
                  else
                    Steno.config.context.data.delete('otel_trace_id')
                    Steno.config.context.data.delete('otel_span_id')
                  end
                  # Add events to the span
                  add_events(span, job)
                  # Call the job
                  yield job
                end
              rescue Exception => e # rubocop:disable Lint/RescueException
                job_root_span&.record_exception(e)
                job_root_span&.status = Status.error("Unhandled exception of type: #{e.class}")
                raise e
              ensure
                job_root_span&.finish
              end
            end

            private

            def start_predefined_root_span(job, kind: :consumer, attributes: {}, links: [])
              span = Trace.current_span
              span_context = span.context
              span_name = "DelayedJobQueue #{job_queue(job)}: #{job_name(job)} process"
              attempts = job.respond_to?(:attempts) ? job.attempts : 0
              if span_context.valid? && attempts == 0
                start_current_span(span, span_name, kind, attributes, links)
              else
                tracer.start_span(span_name, attributes:, links:, kind:)
              end
            end

            def start_current_span(span, name, kind, attributes, links)
              span_id = span.context.span_id
              trace_id = span.context.trace_id

              sampler = SDK::Trace::Samplers.parent_based(root: SDK::Trace::Samplers::ALWAYS_OFF)
              result = sampler.should_sample?(trace_id: trace_id, parent_context: nil, links: links, name: name, kind: kind, attributes: attributes)

              return Trace.non_recording_span(Trace::SpanContext.new(trace_id: trace_id, span_id: span_id, tracestate: result.tracestate)) unless result.recording? && !@stopped

              trace_flags = result.sampled? ? Trace::TraceFlags::SAMPLED : Trace::TraceFlags::DEFAULT
              context = Trace::SpanContext.new(trace_id: trace_id, span_id: span_id, trace_flags: trace_flags, tracestate: result.tracestate)
              attributes = attributes&.merge(result.attributes) || result.attributes.dup

              create_new_span(context, name, kind, attributes, links)
            end

            def create_new_span(context, name, kind, attributes, links)
              SDK::Trace::Span.new(
                context,
                Context.empty,
                Trace::Span::INVALID,
                name,
                kind,
                Trace::SpanContext::INVALID.span_id,
                tracer_provider_span_limits,
                tracer_provider_span_processors,
                attributes,
                links,
                nil,
                tracer_provider_resource,
                tracer_instrumentation_scope
              )
            end

            def current_span_context(context: Context.current)
              Context.with_current(context) { Trace.current_span.context }
            end

            def build_attributes(job)
              {
                'messaging.system' => 'delayed_job',
                'messaging.destination' => job_queue(job),
                'messaging.destination_kind' => 'queue',
                'messaging.delayed_job.name' => job_name(job),
                'messaging.delayed_job.guid' => job_guid(job),
                'messaging.delayed_job.priority' => job.priority
              }
            end

            def add_events(span, job)
              span.add_event('run_at', timestamp: job.run_at) if job.run_at
              span.add_event('locked_at', timestamp: job.locked_at) if job.locked_at
            end

            def enabled?
              CCDelayedJob::Instrumentation.instance.enabled?
            end

            def tracer
              CCDelayedJob::Instrumentation.instance.tracer
            end

            def tracer_provider_span_limits
              tracer.instance_variable_get(:@tracer_provider).instance_variable_get(:@span_limits)
            end

            def tracer_provider_span_processors
              tracer.instance_variable_get(:@tracer_provider).instance_variable_get(:@span_processors)
            end

            def tracer_provider_resource
              tracer.instance_variable_get(:@tracer_provider).instance_variable_get(:@resource)
            end

            def tracer_instrumentation_scope
              tracer.instance_variable_get(:@instrumentation_scope)
            end

            def propagator
              @propagator ||= Trace::Propagation::TraceContext::TextMapPropagator.new
            end

            def job_name(job)
              # If Delayed Job is used via ActiveJob then get the job name from the payload
              if job.payload_object.respond_to?(:job_data)
                job.payload_object.job_data['job_class']
              else
                job.name
              end
            end

            def job_queue(job)
              job.queue || 'default'
            end

            def job_guid(job)
              if job.respond_to?(:guid)
                job.guid
              else
                ''
              end
            end
          end

          callbacks do |lifecycle|
            lifecycle.around(:enqueue, &method(:instrument_enqueue))
            lifecycle.around(:invoke_job, &method(:instrument_invoke))
          end
        end
      end
    end
  end
end
