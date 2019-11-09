# Example of using rotatable users

This is a demo project for rotatable users.

It sets up 2 IAM users, `app-bot` and `app-bot1`, that have permission to get a file from S3. Each user has a corresponding Secrets Manager secret which contains their access key and secret. There is also a lambda function that uses the creds from Secrets Manager to access the S3 file.

It also uses the rotator module which creates 2 lambdas:
* rotateAccessKey: This function is kicked off by the secrets' rotation feature and creates a new access key/secret, tests it, and finally updates the secret value.
* cleanupAccessKey: This function monitors for inactive access keys and deletes them.


### Try it out

Build the tester lambda app
```
make build
```

Apply the terraform
```
make init
make plan
make apply
```

You can reset the secrets/keys, and iniate new rotations:
```
make reset
../bin/rotate.sh
```

If you want to tear it all down and start again:
```
make destroy
```

### Troubleshooting
During the first rotation attempt, you may see an `AccessDeniedException` when the lambda attempts to get the secret value for the first time. This can be caused by a race condition setting the lambdas and IAM permissions. It should resolve itself on the second retry.

During the `testSecret` step of rotation, you may see this error in the logs: `InvalidAccessKeyId: The AWS Access Key Id you provided does not exist in our records.`. This is due to the eventually consistency nature of IAM access keys. Lambda will retry the `testSecret` step, and it should succeed on a subsequent attempt.
