RSpec.shared_examples 'an access control' do |operation, table|
  describe "#{operation}? and #{operation}_with_token?" do
    table.each do |role, expected_return_value|
      it "returns #{expected_return_value} if user is a(n) #{role}" do
        org_if_defined = respond_to?(:org) ? org : nil
        space_if_defined = respond_to?(:space) ? space : nil

        set_current_user_as_role(role: role, org: org_if_defined, space: space_if_defined, user: user)

        actual_with_token = subject.can?("#{operation}_with_token".to_sym, object)

        op_params_if_defined = respond_to?(:op_params) ? op_params : nil

        if op_params_if_defined.present?
          actual_without_token = subject.can?(operation, object, params=op_params_if_defined)
        else
          actual_without_token = subject.can?(operation, object)
        end

        actual = actual_with_token && actual_without_token

        expect(actual).to eq(expected_return_value),
          "role #{role}: expected #{expected_return_value}, got: #{actual}"
      end
    end
  end
end

RSpec.shared_examples 'a feature flag-disabled access control' do |operation, table|
  describe "#{operation}? and #{operation}_with_token?" do
    table.each do |role, allowed_or_raise|
      it "returns #{allowed_or_raise} if user is a(n) #{role}" do
        org_if_defined = respond_to?(:org) ? org : nil
        space_if_defined = respond_to?(:space) ? space : nil

        set_current_user_as_role(role: role, org: org_if_defined, space: space_if_defined, user: user)

        saved_error = nil
        actual = false

        op_params_if_defined = respond_to?(:op_params) ? op_params : nil

        begin
          actual_with_token = subject.can?("#{operation}_with_token".to_sym, object)

          if op_params_if_defined.present?
            actual_without_token = subject.can?(operation, object, params=op_params_if_defined)
          else
            actual_without_token = subject.can?(operation, object)
          end

          actual = actual_with_token && actual_without_token
        rescue => e
          saved_error = e
        end

        allowed = actual && saved_error.blank?

        expect(allowed).to eq(allowed_or_raise),
          "role #{role}: expected #{allowed_or_raise}, got: #{allowed}"
      end
    end
  end
end
