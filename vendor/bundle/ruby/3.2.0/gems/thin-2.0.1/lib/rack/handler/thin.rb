# frozen_string_literal: true

require 'rack/handler'
require_relative '../../thin/rackup/handler'

module Rack
  module Handler
    class Thin < ::Thin::Rackup::Handler
    end

    register :thin, Thin.to_s
  end
end
