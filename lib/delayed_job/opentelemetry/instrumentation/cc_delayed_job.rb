# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'opentelemetry'
require 'opentelemetry-instrumentation-base'

module OpenTelemetry
  module Instrumentation
    module CCDelayedJob
    end
  end
end

require_relative 'cc_delayed_job/instrumentation'
require_relative 'cc_delayed_job/version'
