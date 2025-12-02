module Allowy

  # This module provides the default and common context for checking the permissions.
  # It is mixed into controllers in Rails by default and provides an easy way to reuse it
  # in other parts of the application (RSpec, Cucumber or standalone).
  # For example, you can use this code in your Cucumber features:
  #
  #   @example
  #   class CucumberContext
  #     include Allowy::Context
  #     attr_accessor :current_user
  #
  #     def initialize(user)
  #       @current_user = user
  #     end
  #
  # And then you can easily check the permissions like so:
  #
  #   @example
  #   CucumberContext.new(that_user).can?(:create, Blog)
  #   CucumberContext.new(that_user).should be_able_to :create, Blog
  module Context
    extend ActiveSupport::Concern


    def allowy_context
      self
    end

    def current_allowy
      @current_allowy ||= ::Allowy::Registry.new(allowy_context)
    end

    def can?(action, subject, *args)
      current_allowy.access_control_for!(subject).can?(action, subject, *args)
    end

    def cannot?(action, subject, *args)
      current_allowy.access_control_for!(subject).cannot?(action, subject, *args)
    end

    def authorize!(action, subject, *args)
      current_allowy.access_control_for!(subject).authorize!(action, subject, *args)
    end
  end

end
