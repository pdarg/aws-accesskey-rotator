package main

import (
	"bytes"
	"context"
	"encoding/json"
	"os"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/credentials"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/aws/aws-sdk-go/service/secretsmanager"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
)

var (
	testBucket string
	testObject string
	sess       = session.Must(session.NewSession())
	secrets    = secretsmanager.New(sess)
)

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

func Handler(ctx context.Context) error {
	log.Info("Running fake app")

	if os.Getenv("TEST_BUCKET") == "" {
		log.Errorf("Missing TEST_BUCKET in envrionment")
		return errors.New("Missing TEST_BUCKET in envrionment")
	}

	if os.Getenv("TEST_OBJECT") == "" {
		log.Errorf("Missing TEST_OBJECT in envrionment")
		return errors.New("Missing TEST_OBJECT in envrionment")
	}

	testBucket = os.Getenv("TEST_BUCKET")
	testObject = os.Getenv("TEST_OBJECT")

	log.Infof("Using TEST_BUCKET=%s TEST_OBJECT=%s", testBucket, testObject)

	result, err := secrets.ListSecretsWithContext(ctx, &secretsmanager.ListSecretsInput{})
	if err != nil {
		log.Infof("Error listing secret %s", err)
		return err
	}

	for _, secret := range result.SecretList {

		rotatable := false
		if secret.Tags != nil {
			for _, tag := range secret.Tags {
				if *tag.Key == "Rotatable" && *tag.Value == "true" {
					rotatable = true
					break
				}
			}
		}
		if rotatable == false {
			continue
		}

		accessKey, err := getSecret(&ctx, secret.Name)
		if err != nil {
			log.Infof("Error fetching secret %s: %s", *secret.Name, err)
			continue
		}

		log.Infof("Running fake app for %s", *secret.Name)
		log.Infof("User %s", accessKey.UserName)

		err = useKey(accessKey, testBucket, testObject)
		if err != nil {
			log.Infof("Error testing secret %s / %s: %s", *secret.Name, accessKey.Key, err)
			continue
		}
	}

	return nil
}

func getSecret(ctx *context.Context, secretID *string) (*AccessKeySecret, error) {
	secret, err := secrets.GetSecretValueWithContext(*ctx, &secretsmanager.GetSecretValueInput{
		SecretId: secretID,
	})
	if err != nil {
		return nil, errors.Wrap(err, "failed to get secret")
	}

	accessKey := AccessKeySecret{}
	err = json.Unmarshal([]byte(*secret.SecretString), &accessKey)
	if err != nil {
		return nil, errors.Wrap(err, "failed to decode secret")
	}

	return &accessKey, nil
}

func useKey(accessKey *AccessKeySecret, testBucket string, testObject string) error {
	testSess, err := session.NewSession(&aws.Config{
		Credentials: credentials.NewStaticCredentials(accessKey.Key, accessKey.Secret, ""),
	})
	if err != nil {
		return errors.Wrap(err, "authenticating with new key")
	}

	svc := s3.New(testSess)
	result, err := svc.GetObject(&s3.GetObjectInput{
		Bucket: aws.String(testBucket),
		Key:    aws.String(testObject),
	})
	if err != nil {
		return errors.Wrap(err, "using new key")
	}

	buf := new(bytes.Buffer)
	buf.ReadFrom(result.Body)
	log.Infof("Got data: %s", buf.String())

	return nil
}

func main() {
	lambda.Start(Handler)
}
