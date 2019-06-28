package main

import (
	"bytes"
	"context"
	"encoding/json"
	"os"
	"time"

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
	sess    = session.Must(session.NewSession())
	secrets = secretsmanager.New(sess)
)

const (
	region     = "us-west-2"
	testBucket = "rotate-key-test-bucket"
	testObject = "test"
)

type TesterEvent struct {
	SecretId string `json:"SecretId"`
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

func Handler(ctx context.Context, event TesterEvent) error {
	log.WithFields(log.Fields{
		"secret": event.SecretId,
	}).Info("Running fake app using secret")

	accessKey, err := getSecret(&ctx, &event.SecretId)
	if err != nil {
		return err
	}

	log.Infof("Running fake app for %s", event.SecretId)
	log.Infof("User %s", accessKey.UserName)

	err = useKey(accessKey)
	if err != nil {
		return err
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

func useKey(accessKey *AccessKeySecret) error {
	testSess, err := session.NewSession(&aws.Config{
		Region:      aws.String(region),
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
