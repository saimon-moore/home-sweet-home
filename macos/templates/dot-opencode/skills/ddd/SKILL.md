---
name: ddd
description: Domain-driven design — bounded contexts, ubiquitous language, tactical patterns (use when domain complexity warrants it)
---

## When to Load

Use when: distinct subdomains, naming drift between code and team language, complex entity lifecycle or invariants.

Skip when: simple CRUD, plain functions suffice, no shared domain language. The `software-design` skill covers it.

## Strategic

- **Bounded Contexts**: Identify, name, enforce. Different contexts may model the same real-world thing differently.
- **Ubiquitous Language**: Code, tests, commits, conversation share the same terms. Wrong naming = modeling problem.
- **Context Mapping**: Name the relationship (shared kernel, anti-corruption layer, conformist, open host).

## Tactical (only when complexity justifies it)

- **Aggregates**: Cluster entities sharing invariants. One root. Keep small.
- **Value Objects**: Immutable, equality by value. Use for domain concepts (Money, Email, DateRange).
- **Domain Events**: Past tense. Describe what happened, not what to do.
- **Repositories**: One per aggregate. Return aggregates.

## In Conversation

1. Name the bounded context.
2. Flag language mismatches between code and domain.
3. Suggest tactical patterns only when the specific complexity demands them.
