# Route Policies OpenAPI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the existing V3 route-policy API to the current modular Cloud Foundry OpenAPI specification.

**Architecture:** Add route-policy-specific schemas and request bodies under `docs/openapi/apis/cf/latest`, define all five operations in one path component, and register those components in the latest OpenAPI entrypoint. Reuse the existing metadata, relationship, link, pagination, included-resource, and error components.

**Tech Stack:** OpenAPI 3.1 YAML, Redocly CLI, Node.js, Yarn.

---

## File Map

Create these focused components:

- `docs/openapi/apis/cf/latest/components/schemas/RoutePolicySource.yaml`: supported `source` selector formats.
- `docs/openapi/apis/cf/latest/components/schemas/RoutePolicyRelationships.yaml`: route and source-derived response relationships.
- `docs/openapi/apis/cf/latest/components/schemas/RoutePolicy.yaml`: individual route-policy response.
- `docs/openapi/apis/cf/latest/components/schemas/RoutePolicyList.yaml`: paginated route-policy response.
- `docs/openapi/apis/cf/latest/components/requestBodies/RoutePolicyCreateRequestBody.yaml`: create payload.
- `docs/openapi/apis/cf/latest/components/requestBodies/RoutePolicyUpdateRequestBody.yaml`: metadata-only update payload.
- `docs/openapi/apis/cf/latest/paths/RoutePolicies.yaml`: collection and member operations.

Modify these registries:

- `docs/openapi/apis/cf/latest/openapi.yaml`: tag, schema, request-body, and path registrations.

Do not modify CAPI controllers, messages, presenters, legacy API documentation, numbered OpenAPI versions, or shared components unless linting demonstrates that a shared component must be extended.

The completed contract must expose these five operations: `GET /v3/route_policies`,
`GET /v3/route_policies/{guid}`, `POST /v3/route_policies`,
`PATCH /v3/route_policies/{guid}`, and `DELETE /v3/route_policies/{guid}`.
The collection must expose `guids`, `route_guids`, `space_guids`, `sources`,
`source_guids`, `label_selector`, `include`, `page`, `per_page`, `order_by`,
`created_ats`, and `updated_ats`.

### Task 1: Establish Baseline

**Files:** None.

- [ ] **Step 1: Confirm the implementation branch and clean baseline.**

Run from `capi-release/src/cloud_controller_ng`:

```bash
git status --short --branch
```

Expected: branch `issue-5427-route-policies-openapi` is based on `origin/main`; the worktree is clean if the approved design and this plan have already been committed.

- [ ] **Step 2: Run the existing OpenAPI checks before changing the spec.**

Run from `capi-release/src/cloud_controller_ng/docs/openapi`:

```bash
yarn lint
yarn build
```

Expected: both commands exit successfully and `dist/latest/openapi.yaml` is generated. If dependencies are absent, run `yarn install --frozen-lockfile` once, then repeat both checks.

### Task 2: Add Route-Policy Primitive Schemas

**Files:**
- Create: `docs/openapi/apis/cf/latest/components/schemas/RoutePolicySource.yaml`
- Create: `docs/openapi/apis/cf/latest/components/schemas/RoutePolicyRelationships.yaml`

- [ ] **Step 1: Define the source selector schema.**

Create `RoutePolicySource.yaml` with the exact supported values and UUID-bearing forms:

```yaml
oneOf:
  - type: string
    enum:
      - cf:any
  - type: string
    pattern: '^cf:(app|space|org):[0-9a-f-]+$'
description: |
  The caller selector for a route policy. Use `cf:app:<uuid>` for one app,
  `cf:space:<uuid>` for all apps in a space, `cf:org:<uuid>` for all apps in
  an organization, or `cf:any` for any authenticated caller.
examples:
  - cf:app:d76446a1-f429-4444-8797-be2f78b75b08
  - cf:any
```

- [ ] **Step 2: Define response relationships.**

Create `RoutePolicyRelationships.yaml` with four required relationship keys. Each relationship uses the existing nullable `RelationshipToOne` shape because only the route relationship and the source-matching app, space, or organization relationship contain data:

```yaml
type: object
required:
  - route
  - app
  - space
  - organization
properties:
  route:
    $ref: './RelationshipToOne.yaml'
    description: The route protected by this policy
  app:
    $ref: './RelationshipToOne.yaml'
    description: The app selected by a `cf:app:<uuid>` source, otherwise null
  space:
    $ref: './RelationshipToOne.yaml'
    description: The space selected by a `cf:space:<uuid>` source, otherwise null
  organization:
    $ref: './RelationshipToOne.yaml'
    description: The organization selected by a `cf:org:<uuid>` source, otherwise null
description: Relationships exposed by a route policy
```

- [ ] **Step 3: Check the new primitive schema files.**

Run from `docs/openapi`:

```bash
git diff --check
```

Expected: no whitespace errors are reported. Full YAML and reference validation is deferred until the new files are registered in the entrypoint.

- [ ] **Step 4: Commit the primitive schemas.**

```bash
git add docs/openapi/apis/cf/latest/components/schemas/RoutePolicySource.yaml docs/openapi/apis/cf/latest/components/schemas/RoutePolicyRelationships.yaml
git commit -m "docs: add route policy primitive schemas"
```

### Task 3: Add Route-Policy Resource Schemas

**Files:**
- Create: `docs/openapi/apis/cf/latest/components/schemas/RoutePolicy.yaml`
- Create: `docs/openapi/apis/cf/latest/components/schemas/RoutePolicyList.yaml`

- [ ] **Step 1: Define the individual resource.**

Create `RoutePolicy.yaml`:

```yaml
type: object
allOf:
  - $ref: './BaseSchema.yaml'
  - properties:
      source:
        $ref: './RoutePolicySource.yaml'
      metadata:
        $ref: './Metadata.yaml'
      relationships:
        $ref: './RoutePolicyRelationships.yaml'
      links:
        type: object
        required:
          - self
          - route
        properties:
          self:
            $ref: './Link.yaml'
            description: The URL to get this route policy
          route:
            $ref: './Link.yaml'
            description: The URL to get the route protected by this policy
      included:
        $ref: './IncludedResources.yaml'
        description: Related resources included by the `include` query parameter
required:
  - guid
  - created_at
  - updated_at
  - source
  - metadata
  - relationships
  - links
description: |
  A route policy controls which Cloud Foundry app, space, organization, or
  authenticated caller can access a route on a domain with route-policy
  enforcement enabled.
```

- [ ] **Step 2: Define the paginated collection.**

Create `RoutePolicyList.yaml`:

```yaml
type: object
required:
  - pagination
  - resources
properties:
  pagination:
    $ref: './Pagination.yaml'
  resources:
    type: array
    items:
      $ref: './RoutePolicy.yaml'
  included:
    $ref: './IncludedResources.yaml'
    description: Related resources included by the `include` query parameter
description: A paginated list of route policies
```

- [ ] **Step 3: Check the new resource schema files.**

Run from `docs/openapi`:

```bash
git diff --check
```

Expected: no whitespace errors are reported. Full schema-reference validation is performed after registration in Task 6.

- [ ] **Step 4: Commit the resource schemas.**

```bash
git add docs/openapi/apis/cf/latest/components/schemas/RoutePolicy.yaml docs/openapi/apis/cf/latest/components/schemas/RoutePolicyList.yaml
git commit -m "docs: describe route policy resources"
```

### Task 4: Add Route-Policy Request Bodies

**Files:**
- Create: `docs/openapi/apis/cf/latest/components/requestBodies/RoutePolicyCreateRequestBody.yaml`
- Create: `docs/openapi/apis/cf/latest/components/requestBodies/RoutePolicyUpdateRequestBody.yaml`

- [ ] **Step 1: Define the create request.**

Create `RoutePolicyCreateRequestBody.yaml`:

```yaml
description: Route policy object that needs to be created
required: true
content:
  application/json:
    schema:
      type: object
      additionalProperties: false
      required:
        - source
        - relationships
      properties:
        source:
          $ref: '../schemas/RoutePolicySource.yaml'
        relationships:
          type: object
          additionalProperties: false
          required:
            - route
          properties:
            route:
              type: object
              additionalProperties: false
              required:
                - data
              properties:
                data:
                  type: object
                  additionalProperties: false
                  required:
                    - guid
                  properties:
                    guid:
                      type: string
                      format: uuid
                      description: GUID of the route to protect
        metadata:
          $ref: '../schemas/Metadata.yaml'
    examples:
      app:
        summary: Allow one app to access a route
        value:
          source: cf:app:d76446a1-f429-4444-8797-be2f78b75b08
          relationships:
            route:
              data:
                guid: 89b32bd6-688f-4424-b94f-2e2c86495a5f
          metadata:
            labels:
              team: frontend
            annotations:
              description: Allow frontend app to call backend API
      any:
        summary: Allow any authenticated caller to access a route
        value:
          source: cf:any
          relationships:
            route:
              data:
                guid: 89b32bd6-688f-4424-b94f-2e2c86495a5f
```

- [ ] **Step 2: Define the metadata-only update request.**

Create `RoutePolicyUpdateRequestBody.yaml`:

```yaml
description: Route policy metadata to update; source and route are immutable
required: true
content:
  application/json:
    schema:
      type: object
      additionalProperties: false
      properties:
        metadata:
          $ref: '../schemas/Metadata.yaml'
    examples:
      default:
        summary: Update route policy metadata
        value:
          metadata:
            labels:
              team: backend
            annotations:
              note: Updated contact information
```

- [ ] **Step 3: Commit the request bodies.**

```bash
git add docs/openapi/apis/cf/latest/components/requestBodies/RoutePolicyCreateRequestBody.yaml docs/openapi/apis/cf/latest/components/requestBodies/RoutePolicyUpdateRequestBody.yaml
git commit -m "docs: describe route policy request bodies"
```

### Task 5: Define the Route-Policy Operations

**Files:**
- Create: `docs/openapi/apis/cf/latest/paths/RoutePolicies.yaml`

- [ ] **Step 1: Add the collection operations and filters.**

Create the `/v3/route_policies` section of `RoutePolicies.yaml` with these exact shared parameters and route-policy filters:

```yaml
/v3/route_policies:
  get:
    summary: List route policies
    description: Retrieve route policies visible to the current user.
    operationId: listRoutePolicies
    tags:
      - Route Policies
    parameters:
      - $ref: ../components/parameters/Page.yaml
      - $ref: ../components/parameters/PerPage.yaml
      - $ref: ../components/parameters/OrderBy.yaml
      - $ref: ../components/parameters/CreatedAts.yaml
      - $ref: ../components/parameters/UpdatedAts.yaml
      - $ref: ../components/parameters/LabelSelector.yaml
      - name: guids
        in: query
        schema:
          type: array
          items:
            type: string
            format: uuid
        description: Comma-delimited route-policy GUIDs to filter by
      - name: route_guids
        in: query
        schema:
          type: array
          items:
            type: string
            format: uuid
        description: Comma-delimited route GUIDs to filter by
      - name: space_guids
        in: query
        schema:
          type: array
          items:
            type: string
            format: uuid
        description: Comma-delimited space GUIDs to filter by route space
      - name: sources
        in: query
        schema:
          type: array
          items:
            $ref: ../components/schemas/RoutePolicySource.yaml
        description: Comma-delimited exact route-policy sources to filter by
      - name: source_guids
        in: query
        schema:
          type: array
          items:
            type: string
            format: uuid
        description: Comma-delimited GUIDs in route-policy sources to filter by
      - name: include
        in: query
        schema:
          type: array
          items:
            type: string
            enum:
              - route
              - source
        description: Include the route and/or source resource in the response
    responses:
      '200':
        description: Successfully retrieved route policies
        content:
          application/json:
            schema:
              $ref: ../components/schemas/RoutePolicyList.yaml
      '400':
        $ref: ../components/responses/BadRequest.yaml
      '401':
        $ref: ../components/responses/Unauthorized.yaml
      '403':
        $ref: ../components/responses/Forbidden.yaml
      '422':
        $ref: ../components/responses/UnprocessableEntity.yaml
      '500':
        $ref: ../components/responses/500.yaml
      '502':
        $ref: ../components/responses/BadGateway.yaml
      '503':
        $ref: ../components/responses/ServiceUnavailable.yaml
  post:
    summary: Create a route policy
    description: Create a route policy for a route on a domain with route-policy enforcement enabled.
    operationId: createRoutePolicy
    tags:
      - Route Policies
    requestBody:
      $ref: ../components/requestBodies/RoutePolicyCreateRequestBody.yaml
    responses:
      '201':
        description: Successfully created route policy
        content:
          application/json:
            schema:
              $ref: ../components/schemas/RoutePolicy.yaml
      '400':
        $ref: ../components/responses/BadRequest.yaml
      '401':
        $ref: ../components/responses/Unauthorized.yaml
      '403':
        $ref: ../components/responses/Forbidden.yaml
      '404':
        $ref: ../components/responses/NotFound.yaml
      '422':
        $ref: ../components/responses/UnprocessableEntity.yaml
      '500':
        $ref: ../components/responses/500.yaml
      '503':
        $ref: ../components/responses/ServiceUnavailable.yaml
```

- [ ] **Step 2: Add the member operations.**

Append the `/v3/route_policies/{guid}` section:

```yaml
/v3/route_policies/{guid}:
  get:
    summary: Get a route policy
    description: Retrieve a route policy and optionally include its route or source resource.
    operationId: getRoutePolicy
    tags:
      - Route Policies
    parameters:
      - $ref: ../components/parameters/Guid.yaml
      - name: include
        in: query
        schema:
          type: array
          items:
            type: string
            enum:
              - route
              - source
        description: Include the route and/or source resource in the response
    responses:
      '200':
        description: Successfully retrieved route policy
        content:
          application/json:
            schema:
              $ref: ../components/schemas/RoutePolicy.yaml
      '401':
        $ref: ../components/responses/Unauthorized.yaml
      '403':
        $ref: ../components/responses/Forbidden.yaml
      '404':
        $ref: ../components/responses/NotFound.yaml
      '422':
        $ref: ../components/responses/UnprocessableEntity.yaml
  patch:
    summary: Update a route policy
    description: Update route-policy labels and annotations. The source and route relationship are immutable.
    operationId: updateRoutePolicy
    tags:
      - Route Policies
    parameters:
      - $ref: ../components/parameters/Guid.yaml
    requestBody:
      $ref: ../components/requestBodies/RoutePolicyUpdateRequestBody.yaml
    responses:
      '200':
        description: Successfully updated route policy
        content:
          application/json:
            schema:
              $ref: ../components/schemas/RoutePolicy.yaml
      '400':
        $ref: ../components/responses/BadRequest.yaml
      '401':
        $ref: ../components/responses/Unauthorized.yaml
      '403':
        $ref: ../components/responses/Forbidden.yaml
      '404':
        $ref: ../components/responses/NotFound.yaml
      '422':
        $ref: ../components/responses/UnprocessableEntity.yaml
      '500':
        $ref: ../components/responses/500.yaml
      '503':
        $ref: ../components/responses/ServiceUnavailable.yaml
  delete:
    summary: Delete a route policy
    description: Delete a route policy and remove access for its source on the route.
    operationId: deleteRoutePolicy
    tags:
      - Route Policies
    parameters:
      - $ref: ../components/parameters/Guid.yaml
    responses:
      '204':
        description: Successfully deleted route policy
      '401':
        $ref: ../components/responses/Unauthorized.yaml
      '403':
        $ref: ../components/responses/Forbidden.yaml
      '404':
        $ref: ../components/responses/NotFound.yaml
```

- [ ] **Step 3: Lint the path file after it is reachable through a temporary direct command.**

Before registration, check the path file for whitespace errors from `docs/openapi`:

```bash
git diff --check
```

Expected: no whitespace errors are reported. Full YAML parsing and reference validation is performed after registration in Task 6.

- [ ] **Step 4: Commit the route-policy operations.**

```bash
git add docs/openapi/apis/cf/latest/paths/RoutePolicies.yaml
git commit -m "docs: add route policy OpenAPI operations"
```

### Task 6: Register the Latest Specification

**Files:**
- Modify: `docs/openapi/apis/cf/latest/openapi.yaml:12-362`

- [ ] **Step 1: Add the `Route Policies` tag.**

Insert after the existing `Routes` tag in `openapi.yaml`:

```yaml
  - name: Route Policies
    description: "Route policies control which callers can access routes on identity-aware domains."
```

- [ ] **Step 2: Register route-policy schemas.**

Insert under `components.schemas`:

```yaml
    RoutePolicySource:
      $ref: './components/schemas/RoutePolicySource.yaml'
    RoutePolicyRelationships:
      $ref: './components/schemas/RoutePolicyRelationships.yaml'
    RoutePolicy:
      $ref: './components/schemas/RoutePolicy.yaml'
    RoutePolicyList:
      $ref: './components/schemas/RoutePolicyList.yaml'
```

- [ ] **Step 3: Register route-policy request bodies.**

Insert under `components.requestBodies`:

```yaml
    RoutePolicyCreateRequestBody:
      $ref: './components/requestBodies/RoutePolicyCreateRequestBody.yaml'
    RoutePolicyUpdateRequestBody:
      $ref: './components/requestBodies/RoutePolicyUpdateRequestBody.yaml'
```

- [ ] **Step 4: Register both route-policy paths.**

Insert under `paths`, adjacent to the existing routes entries:

```yaml
  /v3/route_policies:
    $ref: './paths/RoutePolicies.yaml#/~1v3~1route_policies'
  /v3/route_policies/{guid}:
    $ref: './paths/RoutePolicies.yaml#/~1v3~1route_policies~1{guid}'
```

- [ ] **Step 5: Build the registered specification.**

Run from `docs/openapi`:

```bash
yarn lint
yarn build
```

Expected: Redocly resolves every route-policy reference, lint succeeds under the repository configuration, and `dist/latest/openapi.yaml` is generated.

- [ ] **Step 6: Commit the registration changes.**

```bash
git add docs/openapi/apis/cf/latest/openapi.yaml
git commit -m "docs: register route policies in OpenAPI"
```

### Task 7: Verify the Bundled Contract

**Files:** None beyond the generated, ignored `docs/openapi/dist/` output.

- [ ] **Step 1: Confirm all five operations exist in the bundle.**

Run from `docs/openapi`:

```bash
test -s dist/latest/openapi.yaml
rg -n "/v3/route_policies|listRoutePolicies|createRoutePolicy|getRoutePolicy|updateRoutePolicy|deleteRoutePolicy|RoutePolicy" dist/latest/openapi.yaml
```

Expected: both route-policy paths, all five operation IDs, and the route-policy component names appear in the bundled document.

- [ ] **Step 2: Confirm the contract-specific fields exist.**

Run:

```bash
rg -n "source_guids|route_guids|space_guids|cf:any|include|metadata|relationships" dist/latest/openapi.yaml
```

Expected: the collection filters include `route_guids`, `space_guids`, `sources`, and `source_guids`; the resource includes metadata and relationships; and both `route` and `source` are allowed include values.

- [ ] **Step 3: Review the final diff and check whitespace.**

Run from the repository root:

```bash
git diff origin/main...HEAD --check
git diff --stat origin/main...HEAD
git status --short
```

Expected: only the route-policy OpenAPI files and the approved documentation files are changed; no generated `dist/` output is tracked; `git diff --check` is clean.

- [ ] **Step 4: Run the final validation commands together.**

Run from `docs/openapi`:

```bash
yarn lint && yarn build
```

Expected: exit status `0` and a freshly generated `dist/latest/openapi.yaml` containing the complete route-policy contract.
