# frozen_string_literal: true

# Inlined from https://github.com/dnagir/allowy
# See lib/allowy/README.md for details

module Allowy
  # This module provides the interface for implementing the access control actions.
  # In order to use it, mix it into a plain Ruby class and define methods ending with `?`.
  #
  # @example
  #   class PageAccess
  #     include Allowy::AccessControl
  #
  #     def view?(page)
  #       page and page.wiki? and context.user_signed_in?
  #     end
  #   end
  #
  # And then you can check the permissions from a controller:
  #
  # @example
  #   def show
  #     @page = Page.find params[:id]
  #     authorize! :view, @page
  #   end
  #
  module AccessControl
    extend ActiveSupport::Concern

    included do
      attr_reader :context
    end

    def initialize(ctx)
      @context = ctx
    end

    def can?(action, subject, *params)
      allowing, _payload = check_permission(action, subject, *params)
      allowing
    end

    def cannot?(*)
      !can?(*)
    end

    def authorize!(action, subject, *params)
      allowing, payload = check_permission(action, subject, *params)
      raise AccessDenied.new('Not authorized', action, subject, payload) unless allowing
    end

    def deny!(payload)
      throw(:deny, payload)
    end

    private

    def check_permission(action, subject, *params)
      m = "#{action}?"
      raise UndefinedAction.new("The #{self.class.name} needs to have #{m} method. Please define it.") unless respond_to?(m)

      allowing = false
      payload = catch(:deny) { allowing = send(m, subject, *params) }
      [allowing, payload]
    end
  end
end
