require 'active_support'
require 'active_support/core_ext'
require 'active_support/concern'
require 'active_support/inflector'

require "allowy/version"
require "allowy/access_control"
require "allowy/registry"
require "allowy/context"
require "allowy/controller_extensions"

module Allowy
  class UndefinedAccessControl < StandardError; end
  class UndefinedAction < StandardError; end

  class AccessDenied < StandardError
    attr_reader :action, :subject, :payload

    def initialize(message, action, subject, payload=nil)
      @message = message
      @action = action
      @subject = subject
      @payload = payload
    end
  end
end
