RSpec.shared_examples 'an access control' do |operation, table, expected_error=nil|
  describe "#{operation}? and #{operation}_with_token?" do
    table.each do |role, expected_return_value|
      it "returns #{expected_return_value} if user is a(n) #{role}" do
        o = respond_to?(:org) ? org : nil
        s = respond_to?(:space) ? space : nil

        set_current_user_as_role(role: role, org: o, space: s, user: user)

        if respond_to?(:queryer)
          can_read_globally = [:admin, :admin_read_only, :global_auditor].include?(role)
          can_write_globally = role == :admin

          can_write_to_org = can_write_globally
          can_write_to_space = can_write_globally
          can_update_space = can_write_globally

          can_read_from_org = can_read_globally
          can_read_from_space = can_read_globally
          can_read_route = can_read_globally

          if o
            can_read_from_org ||= o.users.include?(user) || o.managers.include?(user) ||
              o.auditors.include?(user) || o.billing_managers.include?(user)
            can_read_from_space ||= o.managers.include?(user)

            can_write_to_org ||= o.managers.include?(user)
            can_read_route ||= o.managers.include?(user) ||
              o.auditors.include?(user)
          end

          if s
            can_read_from_space ||= s.has_member?(user)
            can_write_to_space ||= s.has_developer?(user)
            can_update_space ||= s.managers.include?(user)

            can_read_route ||= s.has_member?(user)
          end

          allow(queryer).to receive(:can_read_globally?).and_return(can_read_globally)
          allow(queryer).to receive(:can_write_globally?).and_return(can_write_globally)

          allow(queryer).to receive(:can_read_from_org?).and_return(can_read_from_org)
          allow(queryer).to receive(:can_read_from_space?).and_return(can_read_from_space)
          allow(queryer).to receive(:can_read_route?).and_return(can_read_route)

          allow(queryer).to receive(:can_write_to_org?).and_return(can_write_to_org)
          allow(queryer).to receive(:can_write_to_space?).and_return(can_write_to_space)
          allow(queryer).to receive(:can_update_space?).and_return(can_update_space)
        end

        saved_error = nil
        actual_with_token = false
        actual_without_token = false
        begin
          actual_with_token = subject.can?("#{operation}_with_token".to_sym, object)

          actual_without_token = if respond_to?(:op_params)
                                   subject.can?(operation, object, op_params)
                                 else
                                   subject.can?(operation, object)
                                 end
        rescue expected_error => e
          saved_error = e
        end

        actual = actual_with_token && actual_without_token && saved_error.blank?

        expect(actual).to eq(expected_return_value),
          "role #{role}: expected #{expected_return_value}, got: #{actual}"
      end
    end
  end
end
