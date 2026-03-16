# frozen_string_literal: true

# Inlined from https://github.com/dnagir/allowy
# See lib/allowy/README.md for details

require 'active_support'
require 'active_support/core_ext'
require 'active_support/concern'
require 'active_support/inflector'

require 'allowy/access_control'
require 'allowy/registry'
require 'allowy/context'

module Allowy
  class UndefinedAccessControl < StandardError; end
  class UndefinedAction < StandardError; end

  class AccessDenied < StandardError
    attr_reader :action, :subject, :payload

    def initialize(message, action, subject, payload=nil)
      super(message)
      @action = action
      @subject = subject
      @payload = payload
    end
  end
end
