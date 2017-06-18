# Build & Deployment Mini-Demo

This project illustrates how to build and deploy a simple containerized Python application in an AWS environment.

## Requirements & Design Assumptions

Container deployment will leverage [AWS Elastic Container Service (ECS)](http://docs.aws.amazon.com/AmazonECS/latest/developerguide). It lets us take advantage of underlying infrastructure components such as TLS termination at the [AWS Application Load Balancer (ALB)](http://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html), we can use it without modifying the application, and we can deliver it quickly with a handful of CloudFormation templates for purposes of this exercise.

Arguably ECS is a sub-optimal choice for a permanent installation:
- The deployment system won't be able to be easily run in local development
- It ties the deployment to proprietary AWS upstack services which would make it more difficult for us to migrate to a different provider later.

So for a permanent installation we should consider using a scheduler (preferably a lightweight one such as Hashicorp's [Nomad](https://www.nomadproject.io/) over an overly-complicated system such as Kubernetes) and/or updating the application to use [ContainerPilot](https://github.com/joyent/containerpilot) and the [AutoPilot Pattern](https://github.com/autopilotpattern).

The [build workflow](#build-workflow) assumes that we're using GitHub with a development model such as GitHub Flow, where development is done on feature branches. Features branches are reviewed and tested before being merged to master, and production releases are cut from master. Because the application is very small we're assuming a single repository and not a multi-repository build chain. It also assumes we're using Jenkins CI for building and testing.

The application as originally authored is not suited to be deployed for horizontal scalability because of its reliance on a sqlite database on the local file system. We'll replace this dependency with a MySQL database running on [AWS Relational Database Service (RDS)](https://aws.amazon.com/rds/).

The application can be reached only via TLS, but we'll assume for purposes of this exercise that we can terminate TLS at the edge (the AWS ALB) rather than requiring the application container to handle TLS itself for end-to-end encryption even inside our infrastructure.

## Out-of-Scope

The following items are being treated as out-of-scope for this exercise but would be minimum requirements of a production deployment:

- Standing up and securing a Docker private registry. The demonstration build scripts will push an image to the public Docker Hub.
- Standing up and securing the Jenkins CI server. Jenkins job examples will be provided by assume the existence of Jenkins and that it has all the appropriate credentials (read access to GitHub, write access to the Docker private registry, keys to sign application container images, etc.).
- Obtaining TLS certificates. The AWS ALB can take advantage of AWS Certificate Manager (ACM), or we can terminate TLS at an edge server (ex. [Nginx w/ Let's Encrypt](https://github.com/autopilotpattern/nginx)) in front of the AWS ALB.
- Building out jump hosts for hardening access to ECS instances.
- Building a custom AMI with extra tooling for observability and debugging of production instances.

## Build Workflow

The Jenkins job `app` is configured to receive webhooks from GitHub via the [GitHub Pull Request Builder](https://wiki.jenkins-ci.org/display/JENKINS/GitHub+pull+request+builder+plugin) plugin. This plugin configures a "bot" behavior that makes a comment in each pull request to get approval to build the branch and run the tests. (This workflow is required for any open source application to avoid malicious builds; if the application were closed source we could simply have Jenkins build every branch.

For each branch, the `app` job builds a container image and identifies it with both the git hash and the name of the branch (note that this is called "tagging" in Docker parlance but that's confusing in this context because git also has "tags"). This container image is then pushed to the Docker registry. Note that subsequent builds will update the Docker name (tag) for the branch to point to the current HEAD. For example:

```
# commit 'deadb33f' lands on branch 'myfeature'
$ make build
$ docker images

REPOSITORY   TAG            IMAGE ID
myrepo/app   deadb33f       239a75391dec
myrepo/app   myfeature      239a75391dec

# then commit '0011abba' lands on branch 'myfeature'
$ make build
$ docker images

REPOSITORY   TAG            IMAGE ID
myrepo/app   deadb33f       239a75391dec
myrepo/app   0011abba       8231e6122519
myrepo/app   myfeature      8231e6122519
```

This workflow works equally well for when features land on the `master` branch; this branch will be continuously deployed to production.

## Testing and QA Deployments

The `test.py` application in the source directory is a skeleton for running unit tests. These are run via `make test` as part of the Jenkins job configuration.

By parameterizing the CloudFormation templates for ECS, each branch gets its own stack. Given appropriate AWS credentials, a Jenkins job (not shown here) can deploy that branch via `make create-stack`, which will create a fresh ECS stack for that branch. The job can then run any integration tests required against that stack.


## Production Deployments

The initial setup for the production deployment will be with `make create-stack`, identical to the QA deployment described above. Note the templates provided presuppose a VPC, subnets, security groups, etc. To update the deployment to a new version of the application, running `TAG=<githash> make update-stack` will update the ECS definition to the desired tag.


## Alternative Design Options

*Multiple Repositories:* this example uses a "monorepo" but in a case where we have many different microservices it may make more sense to split the repo up into the various services, each with their own `infra/` directory for application-specific infrastructure, and a separate repo used for shared infrastructure such as the AWS networking configuration, IAM roles, etc.

*VM-based Deployment:* as an alternative to using Docker containers, the Jenkins job could use tools like Chef Zero and/or Packer to build an AWS Machine Image (AMI). The Jenkins job could then create a new Deployment Configuration based on that AMI. In that scenario, deployments would consist of updating the AutoScaling Group (ASG) with the new Deployment Configuration and rolling the instances out.

*Scheduler-less Docker Deployment:* much of the complication of ECS (and Docker schedulers in general) is required because of port mapping. If container density is not a concern -- perhaps because the VM is sized to a single container or because a fixed group of containers is always deployed together snugly on the VM -- then we can take advantage of host networking rather than NAT, and this lets us treat the ASG much as we would in the VM-based deployment.
