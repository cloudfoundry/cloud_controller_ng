# Copyright (c) 2009-2012 VMware, Inc.

class Object
  def metaclass
    class << self; self; end
  end
end

module VCAP::CloudController
  module AccessController
    # the DSL for controllers
    def grant_access
      self.op_access ||= {}
      ops.each { |op| op_access[op] ||= Set.new }

      def full(*args)
        roles = *args
        roles.each do |role|
          op_access.values.each do |v|
            v.add(role)
          end
        end
      end

      def method_missing(meth, *args, &blk)
        if self.ops.include?(meth)
          args.each do |role|
            op_access[meth].add(role)
          end
        else
          super
        end
      end

      yield if block_given?
    end

    def define_access_type(op)
      ops.add(op)
    end

    def role_has_access?(op, role)
      op_access && op_access[op] && op_access[op].include?(role)
    end

    def roles_have_access?(op, roles)
      roles = Set.new(roles) unless roles.is_a?(Set)
      # note: & is set intersection here
      op_access[op] && (op_access[op] & roles).size > 0
    end

    attr_accessor :op_access

    def ops
      @@ops ||= Set.new
    end
  end
end
