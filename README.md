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

The Jenkins job `app` is configured to receive webhooks from GitHub via the [GitHub Pull Request Builder](https://wiki.jenkins-ci.org/display/JENKINS/GitHub+pull+request+builder+plugin) plugin. For each branch, the `app` job builds a container image and identifies it with both the git hash and the name of the branch (note that this is called "tagging" in Docker parlance but that's confusing in this context because git also has "tags"). This container image is then pushed to the Docker registry. Note that subsequent builds will update the Docker name (tag) for the branch to point to the current HEAD. For example:

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
