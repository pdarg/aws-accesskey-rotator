# AWS Access Key Rotation
This is a terraform module that allows you to create IAM users for shared access to an AWS account.

It's a good idea to avoid persistent secrets altogether by using IAM roles. However, this isn't possible for deployments where some clients connect from outside of AWS. In these cases, using a secure secret store like AWS Secret Manager paired with regular credential rotations will greatly improve your security posture.

## How it works
### Resources

* An IAM user that will be used for accessing AWS resources.
* A Secrets Manager secret that will store and share the IAM user's access key.
* Lambda functions to manage the lifecycle of the access key.

Lambda functions:
* `rotateAccessKey`: this is used by the ASM secret's rotataion feature. The rotate lambda will create a new Access Key for the IAM user, test that it works properly to access the test resource, then update the ASM secret's value.
* `cleanuAccessKey`: this is used to deactivate old IAM user access keys after the client application switches to the new key.

### The flow

You have some external applications that need to access resources in AWS. Rather than generating new access keys and updating your applications manually, you want to automate the process.

First, create the new rotatable users with the `aws-accesskey-rotator` module. The new users will have a corresponding Secrets Manager secret that will be kept up to date with a fresh access key. This is done using ASM's rotation configuration.

Every 30 days, ASM kicks off the rotator lambda for each secret. The lambda creates a new access key for the bot, tests it to verify it's working, then updates the secret.

On every deployment, read the latest access key from Secrets Manager and pass it into the application. Rotating secrets is now just a deployment. If your application is deployed frequently or on a scheduler, no action is needed to keep your access keys updated.

## Usage

Minimal example
```
module "rotator" {
  source = "github.com/pdarg/aws-accesskey-rotator//rotator"
}

module "rotatable_bot" {
  source = "github.com/pdarg/aws-accesskey-rotator//rotatable_user"

  user_name          = "RotatableBot"
  secret_name        = "dev/rotatable-bot-key"
  rotator_lambda_arn = module.rotator.rotator_lambda_arn
}
```

For a more in-depth example, see `example/`.
