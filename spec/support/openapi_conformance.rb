# frozen_string_literal: true

# Spike: check the traffic our request specs already generate against the
# OpenAPI description in docs/openapi.
#
# The request specs drive the real rack app through rack-test, so every
# example is a request/response pair the description either covers or
# doesn't. openapi_first wraps that app and records the verdict, which gives
# us contract checking without a deployed CF, a proxy, or a traffic capture.
#
# Off unless OPENAPI_CONFORMANCE is set, so `rake spec` is untouched -- the
# gem isn't even required.
#
#   OPENAPI_CONFORMANCE=1       record violations, fail nothing
#   OPENAPI_CONFORMANCE=strict  raise on the first request/response that
#                               doesn't conform
#
# It reads the bundled description: openapi_first takes a single file and
# docs/openapi is a multi-file redocly source, so `yarn build` has to run first.
module OpenapiConformance
  DESCRIPTION = File.expand_path('../../docs/openapi/dist/latest/openapi.yaml', __dir__)
  OUT_DIR = File.expand_path('../../out', __dir__)
  HTML_REPORT = File.join(OUT_DIR, 'openapi_coverage.html')
  MARKDOWN_REPORT = File.join(OUT_DIR, 'openapi_conformance.md')

  # Rows past this get cut from the markdown -- the HTML report has them all,
  # and a step summary that long is unreadable anyway.
  MAX_ROWS = 50

  # openapi_first takes one reporter. This one writes the HTML report to read
  # after the fact, plus a short markdown digest for the CI log and the job
  # summary. The gem's own terminal reporter prints every untested route,
  # which on a partially-written description is thousands of lines.
  class Reporter
    def initialize(**_options); end

    def report(coverage_result)
      FileUtils.mkdir_p(OUT_DIR)
      OpenapiFirst::Test::Coverage::HtmlReporter.new(output: HTML_REPORT).report(coverage_result)

      markdown = render(coverage_result)
      File.write(MARKDOWN_REPORT, markdown)
      puts markdown
    end

    private

    def render(coverage_result)
      lines = ["## OpenAPI conformance\n"]
      coverage_result.plans.each { |plan| lines.concat(render_plan(plan)) }
      lines.join("\n")
    end

    def render_plan(plan)
      exercised = plan.routes.count { |route| route.requests.any?(&:requested?) }
      violations = violations(plan)

      lines = [
        "- Coverage: **#{plan.coverage.round(2)}%**",
        "- Described routes exercised: **#{exercised}/#{plan.routes.size}**",
        "- Conformance violations: **#{violations.size}**\n"
      ]
      return lines if violations.empty?

      lines << '| Route | What | Error |'
      lines << '| --- | --- | --- |'
      violations.first(MAX_ROWS).each do |route, what, error|
        lines << "| #{route} | #{what} | #{error} |"
      end
      lines << "\n_#{violations.size - MAX_ROWS} more omitted; see the HTML report._" if violations.size > MAX_ROWS
      lines
    end

    # A violation is something the specs actually exercised where every
    # attempt was rejected. Routes nothing touched are a coverage gap, not a
    # contract breach, and they are the overwhelming majority right now.
    def violations(plan)
      plan.routes.flat_map do |route|
        label = "`#{route.request_method.upcase} #{route.path}`"
        bad_requests = route.requests.select { |req| req.requested? && !req.any_valid_request? }
        bad_responses = route.responses.select { |res| res.responded? && !res.any_valid_response? }

        bad_requests.map { |req| [label, 'request', req.last_error_message] } +
          bad_responses.map { |res| [label, "response #{res.status}", res.last_error_message] }
      end
    end
  end

  class << self
    def enabled?
      !ENV['OPENAPI_CONFORMANCE'].to_s.empty?
    end

    def strict?
      ENV['OPENAPI_CONFORMANCE'] == 'strict'
    end

    # Wraps the app the request specs drive. Returns it untouched when the
    # check is off, so a normal run pays nothing.
    def wrap(rack_app)
      return rack_app unless enabled?

      OpenapiFirst::Test.app(rack_app, api: :cloud_controller)
    end

    def setup!
      return unless enabled?

      unless File.exist?(DESCRIPTION)
        raise "OPENAPI_CONFORMANCE is set but #{DESCRIPTION} is missing. " \
              'Build it first: cd docs/openapi && yarn install && yarn build'
      end

      require 'openapi_first'

      OpenapiFirst::Test.setup do |test|
        test.register(DESCRIPTION, as: :cloud_controller)

        # The description covers part of the API, so the request specs hit
        # plenty of endpoints it says nothing about. That is the description
        # being incomplete, not the app being wrong.
        test.ignore_unknown_requests = true

        # Default is to turn a non-conforming request or response into a spec
        # failure. Off unless asked, so one violation doesn't hide the rest of
        # the picture -- and so this can be added without breaking the suite.
        unless strict?
          test.ignore_request_error { true }
          test.response_raise_error = false
        end

        # :warn reports without the exit 2 that an incomplete description
        # would otherwise trigger. Finding out what the number actually is is
        # the point of the spike.
        test.report_coverage = :warn
        test.coverage_reporter = Reporter
      end
    end
  end
end

OpenapiConformance.setup!
