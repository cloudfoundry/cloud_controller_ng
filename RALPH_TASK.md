---
task: Speed up unit test run time
test_command: "bundle exec rspec spec/unit"
---

# Task: Speed Up Unit Tests (Ruby)

Investigate why unit tests take so long to run and speed them up. Most of the time is currently spent loading the tests.

For example:
"bundle exec rspec spec/unit/actions/app_create_spec.rb" takes ~20s to load and ~1.7s to run.

Running spork and/or spring doesn't seem to help substantially, but maybe they're misconfigured?


## Requirements

1. Do NOT modify any existing tests
2. Make the smallest change possible
3. Understand what factors make the tests slow before you implement any solutions
4. Adhere to good coding standards and AGENTS.md

## Success Criteria

1. [x] Document exists explaining why tests are slow
2. [x] Document explains solution(s) to why tests are slow
3. [ ] Tests reliably load/run faster

---

## Ralph Instructions

1. Work on the next incomplete criterion (marked [ ])
1. Consider multiple options
1. Check off completed criteria (change [ ] to [x])
1. When ALL criteria are [x], output: `<ralph>COMPLETE</ralph>`
1. If stuck on the same issue 3+ times, output: `<ralph>GUTTER</ralph>`
