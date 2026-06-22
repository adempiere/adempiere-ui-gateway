# Customizations

## What is a customization?

A customization is an organization-specific fork of the
[adempiere-customizations](https://github.com/adempiere/adempiere-customizations)
template repository.  
It contains Java classes and patches that override or
extend ADempiere models, processes, and validators.  
When built and released,
these classes are compiled into the `adempiere-grpc-server`, `adempiere-zk`,
and `adempiere-processors-service` container images, which are then referenced
by this stack via their image tags in `docker-compose/env_template.env`.

## Dependency chain

```
adempiere-customizations
        ├── adempiere-zk                  ─┐
        ├── adempiere-grpc-server          ├─► adempiere-ui-gateway
        └── adempiere-processors-service  ─┘
```

## How to implement a customization

1. Fork [adempiere-customizations](https://github.com/adempiere/adempiere-customizations)
   into your own GitHub organization.
2. Add your Java classes and library dependencies following the instructions in
   the repository README.
3. When your changes are ready, use the CI/CD automation scripts provided in
   that repository to propagate the new release through the dependency chain up
   to this stack.  
  The scripts are designed to run against **your own fork** of
   each repository — not against the upstream `adempiere` organization
   repositories, where you do not hold the required write and CI/CD trigger
   rights.

Full details — including the step-by-step propagation flow, required
permissions, and script setup instructions — are documented in the
customizations repository:

**[adempiere-customizations — Customization Workflow](https://github.com/adempiere/adempiere-customizations/blob/main/docs/customization-workflow.md)**

---

[Back to README](../README.md)
