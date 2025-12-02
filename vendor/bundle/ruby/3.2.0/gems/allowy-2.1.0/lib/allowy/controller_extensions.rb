require 'active_support/concern'

module Allowy

  module ControllerExtensions
    extend ActiveSupport::Concern
    included do
      include ::Allowy::Context
      helper_method :can?, :cannot?
    end
  end
end

if defined? ActionController
  ActionController::Base.send(:include, Allowy::ControllerExtensions)
end
