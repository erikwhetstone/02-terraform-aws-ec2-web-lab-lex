# Changelog

All notable changes to this lab are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Amazon Linux 2023 `t3.micro` instance running NGINX in a Lab 1 public subnet
- Security group with HTTP from `allowed_http_cidr` and HTTPS-only egress
- IMDSv2 required with hop limit 1, encrypted gp3 root volume, and standard CPU credits
- Success page showing owner, deployment ID, lab, Region, and expiration date
- 1 GiB swap file and retried package install in user data, because dnf
  was killed for lack of memory on `t3.micro` during testing
- Provider account restriction, data-source postconditions for subnet
  membership and Internet routing, and non-blocking checks for wide HTTP
  access and past expiration dates
- IAM training policy that enforces instance type, IMDSv2, and encryption,
  and limits destructive actions to resources tagged `Purpose = Training`
- README, SECURITY, COSTS, TROUBLESHOOTING, architecture, concepts,
  deployment, and cleanup documentation
