package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"time"

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
	log.SetFormatter(&log.JSONFormatter{
		TimestampFormat: time.RFC3339Nano,
		FieldMap: log.FieldMap{
			log.FieldKeyTime: "@timestamp",
		},
	})
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
			return err
		}
		log.Info("Created new key")
	case "setSecret":
		// Nothing to do
	case "testSecret":
		if err := testSecret(&ctx, &event); err != nil {
			return err
		}
		log.Info("AccessKey test success")
	case "finishSecret":
		if err := finishSecret(&ctx, &event); err != nil {
			return err
		}
		log.Info("AccessKey rotate finished")
	default:
		log.Errorf("Unknown step: %s", event.Step)
	}

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
		return err
	}

	// Delete inactive keys
	list, err := listAccessKeys(&accessKey.UserName)
	if err != nil {
		return errors.Wrap(err, "getting access key list")
	}
	if len(list) > 1 {
		return errors.New("user already has 2 active keys. cannot rotate")
	}

	// Create new key
	key, err := createKey(&accessKey.UserName)
	if err != nil {
		return errors.Wrap(err, "creating new access key")
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
		return nil, errors.Wrap(err, fmt.Sprintf("failed to get %s secret", *stage))
	}

	accessKey := AccessKeySecret{}
	err = json.Unmarshal([]byte(*secret.SecretString), &accessKey)
	if err != nil {
		return nil, errors.Wrap(err, fmt.Sprintf("failed to decode %s secret", *stage))
	}

	return &accessKey, nil
}

func testNewKey(accessKey *AccessKeySecret) error {
	testSess, err := session.NewSession(&aws.Config{
		Region:      aws.String(region),
		Credentials: credentials.NewStaticCredentials(accessKey.Key, accessKey.Secret, ""),
	})
	if err != nil {
		return errors.Wrap(err, "authenticating with new key")
	}

	svc := s3.New(testSess)
	_, err = svc.GetObject(&s3.GetObjectInput{
		Bucket: aws.String(testBucket),
		Key:    aws.String(testObject),
	})
	if err != nil {
		return errors.Wrap(err, "using new key")
	}

	return nil
}

func listAccessKeys(userName *string) ([]*iam.AccessKeyMetadata, error) {
	svc := iam.New(sess)
	result, err := svc.ListAccessKeys(&iam.ListAccessKeysInput{
		UserName: userName,
	})
	if err != nil {
		return nil, err
	}

	return result.AccessKeyMetadata, nil
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

func main() {
	lambda.Start(Handler)
}
