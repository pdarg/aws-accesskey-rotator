package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/awserr"
	"github.com/aws/aws-sdk-go/aws/credentials"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/iam"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/aws/aws-sdk-go/service/secretsmanager"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
)

var (
	sess    = session.Must(session.NewSession())
	secrets = secretsmanager.New(sess)
)

const (
	StageCurrent = "AWSCURRENT"
	StagePending = "AWSPENDING"
	region       = "us-west-2"
	testBucket   = "app-bot-test-bucket"
	testObject   = "test"
)

type SecretRotationEvent struct {
	ClientRequestToken string `json:"ClientRequestToken"`
	SecretId           string `json:"SecretId"`
	Step               string `json:"Step"`
}

type AccessKeySecret struct {
	Key      string `json:"Key"`
	Secret   string `json:"Secret"`
	UserName string `json:"UserName"`
}

func init() {
	if os.Getenv("DEBUG") == "true" {
		log.SetLevel(log.DebugLevel)
	}
}

func Handler(ctx context.Context, event SecretRotationEvent) error {
	log.WithFields(log.Fields{
		"token":  event.ClientRequestToken,
		"secret": event.SecretId,
		"step":   event.Step,
	}).Info(fmt.Sprintf("Doing rotation step %s", event.Step))

	switch event.Step {
	case "createSecret":
		if err := createSecret(&ctx, &event); err != nil {
			return errors.Wrap(err, fmt.Sprintf("Caught error in %s step: %s", event.Step, err))
		}
	case "setSecret":
		// Nothing to do
	case "testSecret":
		if err := testSecret(&ctx, &event); err != nil {
			return errors.Wrap(err, fmt.Sprintf("Caught error in %s step: %s", event.Step, err))
		}
	case "finishSecret":
		if err := finishSecret(&ctx, &event); err != nil {
			return errors.Wrap(err, fmt.Sprintf("Caught error in %s step: %s", event.Step, err))
		}
	default:
		log.Errorf("Unknown step: %s", event.Step)
	}
	log.Infof("%s finished", event.Step)

	return nil
}

func createSecret(ctx *context.Context, event *SecretRotationEvent) error {

	accessKey, err := getSecret(ctx, &event.SecretId, aws.String(StagePending))
	if err == nil {
		log.Info("There is already a secret pending. Don't create a new one.")
		return nil
	}

	// Get current secret
	accessKey, err = getSecret(ctx, &event.SecretId, aws.String(StageCurrent))
	if err != nil {
		if aerr, ok := err.(awserr.Error); ok {
			if aerr.Code() == secretsmanager.ErrCodeResourceNotFoundException {
				log.Infof("No %s secret version found", StageCurrent)
			} else {
				return aerr
			}
		} else {
			log.Infof("Unknown exception: ok: %v aerr: %v err: %v", ok, aerr, err)
			return err
		}
	}

	// Create new key
	key, err := createKey(&accessKey.UserName)
	if err != nil {
		if aerr, ok := err.(awserr.Error); ok {
			if aerr.Code() == iam.ErrCodeLimitExceededException {
				return errors.New("user already has 2 active keys. cannot rotate")
			}
		}

		return err
	}

	// Save new value
	accessKey.Key = *key.AccessKeyId
	accessKey.Secret = *key.SecretAccessKey

	b, err := json.Marshal(accessKey)
	secretValue := string(b)

	_, err = secrets.PutSecretValueWithContext(*ctx, &secretsmanager.PutSecretValueInput{
		ClientRequestToken: aws.String(event.ClientRequestToken),
		SecretId:           aws.String(event.SecretId),
		SecretString:       &secretValue,
		VersionStages:      aws.StringSlice([]string{StagePending}),
	})
	if err != nil {
		if awsErr, ok := err.(awserr.Error); ok {
			if awsErr.Code() == secretsmanager.ErrCodeResourceExistsException {
				log.Info("Key already exists. Could be a retry. Skipping error")
				return nil
			}
		}
		return errors.Wrap(err, "writing new key")
	}

	return nil
}

func testSecret(ctx *context.Context, event *SecretRotationEvent) error {
	accessKey, err := getSecret(ctx, &event.SecretId, aws.String(StagePending))
	if err != nil {
		return err
	}

	if err = testNewKey(accessKey); err != nil {
		return errors.Wrap(err, fmt.Sprintf("new key %s is not working", accessKey.Key))
	}

	return nil
}

func finishSecret(ctx *context.Context, event *SecretRotationEvent) error {
	secretInfo, err := secrets.DescribeSecretWithContext(*ctx, &secretsmanager.DescribeSecretInput{
		SecretId: aws.String(event.SecretId),
	})
	if err != nil {
		return errors.Wrap(err, "obtaining secret details")
	}

	var currentVersion, pendingVersion string
	for versionID, stages := range secretInfo.VersionIdsToStages {
		for _, stage := range aws.StringValueSlice(stages) {
			if stage == StageCurrent {
				currentVersion = versionID
			} else if stage == StagePending {
				pendingVersion = versionID
			}
		}
	}

	_, err = secrets.UpdateSecretVersionStageWithContext(*ctx, &secretsmanager.UpdateSecretVersionStageInput{
		SecretId:            aws.String(event.SecretId),
		RemoveFromVersionId: aws.String(currentVersion),
		MoveToVersionId:     aws.String(pendingVersion),
		VersionStage:        aws.String(StageCurrent),
	})
	if err != nil {
		return errors.Wrap(err, "error updating secret stage")
	}

	_, err = secrets.UpdateSecretVersionStageWithContext(*ctx, &secretsmanager.UpdateSecretVersionStageInput{
		SecretId:            aws.String(event.SecretId),
		RemoveFromVersionId: aws.String(pendingVersion),
		VersionStage:        aws.String(StagePending),
	})
	if err != nil {
		return errors.Wrap(err, "error updating secret stage")
	}

	return nil
}

func getSecret(ctx *context.Context, secretID *string, stage *string) (*AccessKeySecret, error) {
	secret, err := secrets.GetSecretValueWithContext(*ctx, &secretsmanager.GetSecretValueInput{
		SecretId:     secretID,
		VersionStage: stage,
	})
	if err != nil {
		return nil, err
	}

	accessKey := AccessKeySecret{}
	err = json.Unmarshal([]byte(*secret.SecretString), &accessKey)
	if err != nil {
		return nil, err
	}

	return &accessKey, nil
}

func createKey(userName *string) (*iam.AccessKey, error) {
	svc := iam.New(sess)
	result, err := svc.CreateAccessKey(&iam.CreateAccessKeyInput{
		UserName: userName,
	})

	if err != nil {
		return nil, err
	}

	return result.AccessKey, nil
}

func testNewKey(accessKey *AccessKeySecret) error {
	testSess, err := session.NewSession(&aws.Config{
		Region:      aws.String(region),
		Credentials: credentials.NewStaticCredentials(accessKey.Key, accessKey.Secret, ""),
	})
	if err != nil {
		return err
	}

	svc := s3.New(testSess)
	_, err = svc.GetObject(&s3.GetObjectInput{
		Bucket: aws.String(testBucket),
		Key:    aws.String(testObject),
	})
	if err != nil {
		return err
	}

	return nil
}

func main() {
	lambda.Start(Handler)
}
