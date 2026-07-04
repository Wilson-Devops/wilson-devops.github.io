# AWS 3-Tier Architecture with Terraform

This project provisions a simple 3-tier AWS architecture in a single VPC:

- Tier 1: Public web tier with an Application Load Balancer and EC2 instances
- Tier 2: Application tier hosted in private subnets behind the ALB
- Tier 3: Data tier with an RDS MySQL instance in private subnets

## Files

- `main.tf` — Core infrastructure resources
- `variables.tf` — Input variables
- `outputs.tf` — Useful outputs
- `versions.tf` — Terraform and provider configuration

## Usage

1. Copy `terraform.tfvars.example` to `terraform.tfvars`
2. Set a strong database password in `terraform.tfvars`
3. Configure AWS credentials with the AWS CLI or environment variables
4. Run:

```bash
terraform init
terraform plan
terraform apply
```

## Notes

- The application tier uses an Auto Scaling Group with two instances by default.
- The database is placed in private subnets and is only reachable from the application tier.
- The ALB exposes the application publicly on port 80.

## GitHub Pages

This repository includes a static site under `docs/index.html` for GitHub Pages.

To deploy:

1. Push the branch to `main`.
2. Enable GitHub Pages for this repo in Settings.
3. Select `main` branch and `/docs` folder as the Pages source.

Expected site URL for this repo:

- `https://wilson-devops.github.io/`

If the site is not yet live at the root URL, rename the repository to `wilson-devops.github.io` and redeploy.
