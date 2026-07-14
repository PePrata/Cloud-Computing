# Limitations & Roadmap

## Known limitations

- **Single EC2 host per region, no ALB/ASG.** Within a region, there is
  no protection against a single-instance failure short of a full
  regional failover — an instance-level crash in `us-east-1` currently
  triggers the same Route 53 health-check-driven failover as a full
  regional outage, which is a heavier response than the fault warrants.
- **Failback is manual.** As detailed in `docs/dr.md`, promoting a read
  replica is one-way; re-establishing the original primary/standby
  direction after a real failover requires manual steps, not a single
  `terraform apply`.
- **Standby has no SQS queues.** To keep the standby region genuinely
  low-cost while it's pilot-light, `terraform/environments/dr` does not
  provision its own `order-created`/`order-status-changed` queues. After
  a real failover, event-driven stock updates between `order-service`
  and `product-service` would not work in the standby region until the
  messaging module is also applied there.
- **Warm-standby app containers aren't running.** Even with
  `standby_instance_state = "running"`, this repo doesn't currently
  start the docker-compose stack on the standby proactively — Ansible
  still needs to be run against it after the EC2 host boots. A fully
  warm standby (containers already serving read traffic) is not
  implemented.
- **Unrestricted SSH ingress** (`0.0.0.0/0` on port 22) on both app
  hosts, because GitHub-hosted runners don't have a stable IP range —
  documented in `docs/security.md`, not silently left in place.
- **All security-group egress rules are `0.0.0.0/0`.** Tighter egress
  (e.g. restricting RDS security groups to no outbound at all, or
  service groups to only their known dependencies) was left as-is from
  the original design to limit scope.
- **`order-status-changed` has no consumer.** Published by
  `order-service` but nothing currently reads it — reserved for a
  future service.
- **No automated cross-region alerting/dashboard** beyond the one
  CloudWatch alarm that drives the Lambda; there's no consolidated
  "which region is currently active" dashboard.
- **Single measured drill, not continuous chaos testing.** The
  `dr-drill.yml` workflow proves the mechanism works and reports one
  RTO number per run; it isn't scheduled or run against varying load
  conditions.

## Roadmap

1. Automate the failback re-seeding steps in `docs/dr.md` into a second
   Terraform-driven workflow (`dr-failback.yml`), rather than a manual
   runbook.
2. Provision the standby's SQS queues (and, ideally, replicate
   in-flight messages or accept the small gap) so event-driven flows
   keep working after a real failover.
3. Move from a single EC2 host per region to an Auto Scaling Group
   behind an ALB, so instance-level failures are handled locally
   without triggering a full regional failover.
4. Replace direct SSH from GitHub Actions with AWS Systems Manager
   Session Manager, removing the need for any inbound port 22 rule.
5. Add a consumer for `order-status-changed` (e.g. a notification
   service) to close the current dead-end event.
6. Tighten security-group egress rules from `0.0.0.0/0` to only the
   destinations each service actually needs.
7. Add a small CloudWatch dashboard showing which region is currently
   serving traffic (derived from the `/shop/<env>/status` SSM
   parameters) so on-call doesn't need to check DNS or Route 53
   directly.
