# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::RestAPI
  # This module enables defining the semantics of coarse grained permissions
  # for operations on an object.
  #
  # There are two main concepts used in this module.  An operation type,
  # e.g. :create, :read, :update, :update_instance_count, etc. and a
  # permission type, e.g. :admin, :developer, etc.
  #
  # The operation type is expected to be represented as a symbol. The
  # permission can really be anything that has can be evaluated for equality.
  #
  # This module doesn't really care about the meaning or representation of a
  # permission.  A type of operation is added to a permission, and then
  # a query can be performed later to check if an entity can perform
  # an operation given a set of permissions.
  #
  # e.g.
  #
  # # sometime in app setup
  # define_permitted_operation :create
  # define_permitted_operation :update_the_foobaz
  #
  # # later when defining a controller class:
  #
  # permissions_required do
  #   # note: admins here could be a module, a string, whatever
  #   create :admin
  #   update_the_foobaz :developer
  # end
  #
  # # and then finally, when preparing to handle a create operation:
  # permission_allows_op?(:create, :admin)
  module PermissionManager
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      # Define a type of permitted operation.  Note that these are shared
      # across *all* controllers.
      #
      # @param [Symbol] op The type of operations being defined.
      def define_permitted_operation(op)
        permitted_ops.add(op)
      end

      # Start the DSL used in the controller classes for setting the
      # required permissions for various types of operations.
      #
      # @param [Block] &blk Block to evaluate in the context of the DSL
      def permissions_required(&blk)
        self.permissions ||= {}
        permitted_ops.each { |op| self.permissions[op] = Set.new }

        controller = self
        k = Class.new do
          extend DefinePermissionsDSL
          setup_dsl(controller)
        end

        k.new.instance_eval(&blk)
      end

      # Predicate to check if a permission or set of permissions
      # allows an operation.
      #
      # Since a given entity might have been granted multiple permissions,
      # we really want to check all of them in a single shot.
      # For example, the user might have permission with both high and low
      # levels of access on the object we are checking.
      #
      # @param [Symbol] op The type of operation to checko
      #
      # @param [Enumerable] permissions A collection of permissions to check.
      #
      # @return [Boolean] True if any of the supplied permissions allow the
      # given operation.
      def op_allowed_by?(op, *perms)
        perms = perms.first if perms.first.respond_to?(:each)
        perms = Set.new(perms) unless perms.is_a?(Set)
        permissions[op] && (permissions[op] & perms).size > 0
      end

      # Predicate to check if a certain type of operation is defined.
      #
      # @param [Symbol] op The operation to check.
      #
      # @return [Boolean] True if the given type of access has been defined via
      # define_access_type.
      def is_operation?(op)
        permitted_ops.include?(op)
      end

      # For internal use by this class and the DSL.
      def permitted_ops
        @@permitted_ops ||= Set.new
      end

      attr_accessor :permissions
    end

    # The DSL for defining permissions.
    #
    # It surfaces a method for each access type, i.e. if you previously did a
    # define_permitted_operation :some_type then when inside
    # define_permissions, the method some_type is a valid method that
    # takes one or more permissions as an argument.
    module DefinePermissionsDSL
      def initialize(controller)
        @controller = controller
      end

      def setup_dsl(controller)
        controller.permitted_ops.each do |op|
          define_method(op) do |*args, &blk|
            perms = *args
            perms.each do |perm|
              controller.permissions[op].add(perm)
            end
          end
        end

        # Helper function that defines a permission set to be allowed to
        # perform every defined operation.
        define_method(:full) do |*args|
          perms = *args
          perms.each do |perms|
            controller.permissions.values.each do |v|
              v.add(perms)
            end
          end
        end
      end
    end
  end
end
