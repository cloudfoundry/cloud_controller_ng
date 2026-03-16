# frozen_string_literal: true

# Inlined from https://github.com/dnagir/allowy
# See lib/allowy/README.md for details

module Allowy
  # This module provides the default and common context for checking the permissions.
  # It is mixed into controllers and provides an easy way to reuse it
  # in other parts of the application (RSpec, Cucumber or standalone).
  #
  # @example
  #   class MyContext
  #     include Allowy::Context
  #     attr_accessor :current_user
  #
  #     def initialize(user)
  #       @current_user = user
  #     end
  #   end
  #
  # And then you can easily check the permissions like so:
  #
  # @example
  #   MyContext.new(that_user).can?(:create, Blog)
  #
  module Context
    extend ActiveSupport::Concern

    def allowy_context
      self
    end

    def current_allowy
      @current_allowy ||= ::Allowy::Registry.new(allowy_context)
    end

    def can?(action, subject, *)
      current_allowy.access_control_for!(subject).can?(action, subject, *)
    end

    def cannot?(action, subject, *)
      current_allowy.access_control_for!(subject).cannot?(action, subject, *)
    end

    def authorize!(action, subject, *)
      current_allowy.access_control_for!(subject).authorize!(action, subject, *)
    end
  end
end
