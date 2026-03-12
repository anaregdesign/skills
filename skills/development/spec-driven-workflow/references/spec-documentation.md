# Spec Documentation

Use this reference when writing or updating `/doc/spec/` for a development request.

## Goal

Document the complete user-visible requirement from the user's point of view before substantial implementation starts.
If no relevant spec exists yet, start by creating the first spec document before moving on to the main implementation workflow.

## Required Characteristics

- Write for people who care about the behavior, not the internal code structure.
- Keep the primary focus on user goals, expected behavior, and acceptance criteria.
- If the request arrives as overly detailed instructions, propose a higher-level goal framing and ask the instruction giver to review it before using it as the spec anchor.
- Keep implementation notes secondary and clearly separated if they are needed.
- Update the spec if the accepted behavior changes during development.

## Recommended Structure

```md
# <Feature or Change Title>

## Summary

## User Problem

## Users and Scenarios

## Scope

## Non-Goals

## User-Visible Behavior

## Acceptance Criteria

## Edge Cases

## Constraints and Dependencies

## Links
```

## What To Capture

- What the user is trying to do
- What pain point or missing capability exists today
- What changes in the visible behavior after the work ships
- What is explicitly out of scope
- What counts as done from the user's perspective
- What edge cases or error paths still matter to the user
- Which constraints or mandated sequencing are truly required, after removing incidental micromanagement
- Which temporary plan file currently tracks the work, when that artifact exists

## Starting From Nothing

- If `/doc/spec/` does not exist, create it first.
- If `/doc/spec/` exists but the requested work has no matching document yet, create a new initial spec file before drafting the main implementation.
- The initial spec does not need to predict every implementation detail, but it should already cover user goals, visible behavior, acceptance criteria, and non-goals.
- If the original request is a long list of detailed instructions, show a condensed goal-and-constraints framing to the instruction giver and get review on that framing before you expand it into a plan.

## What To Avoid

- Do not start with folder layout, classes, Hook names, or schema details.
- Do not let implementation notes replace acceptance criteria.
- Do not let `/doc/plan.md` replace the user-facing requirement document.
- Do not leave the spec as a vague problem statement without concrete behavior.
- Do not silently replace long step-by-step instructions with your own abstraction; show the proposed higher-level goal and ask for review first.
- Do not keep stale behavior in the spec after the implementation direction changes.

## Quality Check

Before coding substantially, confirm the spec answers these questions:

- Who is the user of this change?
- What can they do after the change that they could not do before?
- What should they see when the change succeeds?
- What should they see when common errors or edge cases happen?
- What is not being solved in this request?
- What would make a reviewer say the work is complete?
