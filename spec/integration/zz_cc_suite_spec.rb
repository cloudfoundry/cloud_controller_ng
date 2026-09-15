require 'spec_helper'
require_relative 'app_log_emitter_shared_context'
require_relative 'cors_shared_context'

RSpec.describe 'Integration suite', type: :integration do
  before(:all) do
    start_cc
  end

  after(:all) do
    stop_cc
  end

  include_context 'CORS'
  include_context 'Cloud controller Loggregator Integration'
end
