# aws-accesskey-rotator
This is a demo of using AWS Secret Manager's rotation feature with AWS Access Keys.

### Motivation
It's generally a good idea to avoid persistent secrets altogether by using IAM roles for example. However, this isn't possible for deployments where some clients connect from outside of AWS. In these cases, using a secure secret store like AWS Secret Manager paired with regular credential rotations will greatly improve your security posture.

### Try it out
The following will build the rotator lambda and deploy a demo environment to your AWS account using your default credential profile.
```
make build
make deploy
```
