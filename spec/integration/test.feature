Feature: jkfdlsa


  Scenario:
    When I POST the following JSON to "/some/url":
    """
        {
          "some": "json"
        }
      """

    Then I should receive the following response:
    """
        {
          "something": "else"
        }
      """


    When I POST the following JSON to "/v2/service_instances":
    """
      {
        service_plan_guid: "my-plan-guid",
        name: "my-service",
        space_guid: "my-space-guid"
      }
      """

    Then CC should PUT to "/v2/service_instances/[[:alnum]]+" on the broker with a body including this JSON:
    """
      {
        service_id:
        plan_id:
        space_guid:
        organization_guid:
      }
      """


  Scenario: Attempting to delete a service instance that was never created on the service broker
    Given the broker does not know about a service instance for the CC service instance "some-known-guid"

    When I DELETE the following JSON to "/v2/service_instances/some-known-guid"

    Then CC should send a DELETE request to "/v2/service_instances/some-known-guid" with the following query params:
      | service_id      | plan_id    |
      | some_service_id | my-plan-id |

    When the broker responds with a 410

    Then the service instance should no longer exist in "/v2/service_instances"
    And the CC should respond with a 200 status
