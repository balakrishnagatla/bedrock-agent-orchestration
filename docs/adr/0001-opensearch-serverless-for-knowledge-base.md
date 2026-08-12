# ADR 0001: OpenSearch Serverless as the Knowledge Base vector store

**Status:** Accepted

## Context

The Bedrock Knowledge Base needs a vector store for RAG. Bedrock supports
several backends: OpenSearch Serverless, self-managed OpenSearch, Aurora
PostgreSQL (pgvector), Pinecone, MongoDB Atlas, and (as of late 2025) native
S3 Vectors.

## Decision

Use **OpenSearch Serverless** for both `dev` and `prod`.

## Rationale

- Zero cluster management: no instance sizing, patching, or shard rebalancing
  to own, which matters for a platform team also carrying EKS and the agent
  graph itself.
- Pay-per-OCU billing scales down to near-zero for a `dev` environment with
  sparse traffic, versus a fixed-size self-managed OpenSearch domain.
- First-class support in the `aws-ia/bedrock/aws` module's `create_default_kb`
  path, which provisions the collection, encryption/network/data-access
  policies, and the knowledge base's index field mapping together --
  reducing the amount of hand-written wiring this repo has to own and keep
  correct across module upgrades.
- IAM-native data-plane authorization (OpenSearch Serverless access
  policies keyed on IAM principal ARNs) fits the zero-trust posture used
  everywhere else in this repo -- no separate database credentials to
  rotate or leak.

## Consequences

- OpenSearch Serverless has a non-trivial minimum OCU floor compared to
  S3 Vectors' pure pay-per-use model; for a very low-traffic `dev`
  environment, S3 Vectors (once broadly GA) may be cheaper. Revisit if
  `dev` idle cost becomes material -- see `docs/ARCHITECTURE.md` cost notes.
- OpenSearch Serverless collections are region-scoped and do not support
  cross-region replication natively; disaster recovery requires re-running
  the ingestion pipeline in a second region, not data replication.
