require "spec_helper"

module VCAP::RestAPI
  describe VCAP::RestAPI::PermissionManager do

    def make_controller(&blk)
      k = Class.new do
        include PermissionManager
      end
      k.instance_eval(&blk) unless blk.nil?
      k
    end

    let(:klass_a) { make_controller }
    let(:klass_b) { make_controller }

    describe "#define_permitted_operation" do
      it "should define global permitted operations" do
        klass_a.define_permitted_operation(:some_op)
        klass_a.permitted_ops.should include :some_op
        klass_b.permitted_ops.should include :some_op
        klass_b.define_permitted_operation(:another_op)
        klass_a.permitted_ops.should include :some_op
        klass_b.permitted_ops.should include :some_op
        klass_a.permitted_ops.should include :another_op
        klass_b.permitted_ops.should include :another_op
        klass_b.permitted_ops.should_not include :non_existent
      end
    end

    let(:klass_permission_check) do
      make_controller do
        define_permitted_operation(:some_op)
        define_permitted_operation(:another_op)

        permissions_required do
          some_op :some_perm
          some_op :another_perm
          some_op :yet_another_perm, :and_another_perm
          another_op :some_perm
          full :mega_user
        end
      end
    end

    let(:permissions_allowing_op) do
      [:some_perm, :another_perm, :yet_another_perm, :and_another_perm]
    end

    describe "#set_permission" do
      it "should add DSL methods for each operation type" do
        # we get this for free
        klass_permission_check.should_not be_nil
      end

      it "should add a #full method that grants to all operation types" do
        k = klass_permission_check
        k.op_allowed_by?(:some_op, :mega_user).should be_true
        k.op_allowed_by?(:another_op, :mega_user).should be_true
      end
    end

    describe "#op_allowed_by?" do
      let(:some_perms_allowing_op) do
        [:anon] + permissions_allowing_op + [:low_priv]
      end

      it "should return true when a permission allows an op" do
        k = klass_permission_check
        permissions_allowing_op.each do |perm|
          k.op_allowed_by?(:some_op, perm).should be_true
        end
        k.op_allowed_by?(:another_op, :some_perm).should be_true
      end

      it "should return false when a permission does not include an op" do
        k = klass_permission_check
        (permissions_allowing_op - [:some_perm]).each do |perm|
          k.op_allowed_by?(:another_op, perm).should be_false
        end
      end

      it "should return false when called with a non-existent op" do
        k = klass_permission_check
        k.op_allowed_by?(:does_not_exist, :some_perm).should be_false
        k.op_allowed_by?(:does_not_exist, :mega_user).should be_false
      end

      let(:no_permissions_allowing_op) do
        [:anon, :low_priv]
      end

      it "should return true when any permission in an array can perorm an op" do
        k = klass_permission_check
        k.op_allowed_by?(:some_op,
                         some_perms_allowing_op).should be_true
      end

      it "should return true when any permission in a Set can perorm an op" do
        k = klass_permission_check
        perms = Set.new(some_perms_allowing_op)
        k.op_allowed_by?(:some_op, perms).should be_true
      end

      it "should return true when any permission in the argument list can perform an op" do
        k = klass_permission_check
        k.op_allowed_by?(:some_op,
                         *some_perms_allowing_op).should be_true
      end

      it "should return false when no permission in an array can perform an op" do
        k = klass_permission_check
        k.op_allowed_by?(:some_op,
                         no_permissions_allowing_op).should be_false
      end

      it "should return false when no permissions in a Set can perform an op" do
        k = klass_permission_check
        perms = Set.new(no_permissions_allowing_op)
        k.op_allowed_by?(:some_op, perms).should be_false
      end

      it "should return false when no permissions in the argument list can perform an op" do
        k = klass_permission_check
        k.op_allowed_by?(:some_op,
                         no_permissions_allowing_op).should be_false
      end

      it "should return false when called with an empty array" do
        k = klass_permission_check
        k.op_allowed_by?(:some_op, []).should be_false
      end

      it "should return false when called with an empty Set" do
        k = klass_permission_check
        k.op_allowed_by?(:some_op, Set.new).should be_false
      end

      it "should return false when called with a non-existent operation" do
        k = klass_permission_check
        k.op_allowed_by?(:does_not_exist,
                         some_perms_allowing_op).should be_false
      end
    end
  end
end
