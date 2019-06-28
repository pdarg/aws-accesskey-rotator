package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/iam"
	"github.com/aws/aws-sdk-go/service/secretsmanager"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
)

var (
	sess        = session.Must(session.NewSession())
	secretsSess = secretsmanager.New(sess)
	iamSess     = iam.New(sess)
)

const (
	StageCurrent  = "AWSCURRENT"
	StagePending  = "AWSPENDING"
	StagePrevious = "AWSPREVIOUS"
	region        = "us-west-2"

	InactivitySeconds = 86400 // 24 hours
)

type CleanupEvent struct {
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

func Handler(ctx context.Context, event CleanupEvent) error {
	log.WithFields(log.Fields{
		"secret": event.SecretId,
	}).Info("Cleaning up old secrets")

	accessKey, err := getSecret(&ctx, &event.SecretId, aws.String(StageCurrent))
	if err != nil {
		return err
	}

	log.Infof("Cleaning up secrets for %s", event.SecretId)
	log.Infof("User %s", accessKey.UserName)

	err = cleanupInactiveKeys(&ctx, &accessKey.UserName)
	if err != nil {
		return err
	}

	err = cleanupOldSecrets(&ctx, &event.SecretId, &accessKey.UserName)
	if err != nil {
		return err
	}

	return nil
}

func cleanupInactiveKeys(ctx *context.Context, userName *string) error {
	list, err := listAccessKeys(ctx, userName)
	if err != nil {
		return err
	}
	keyCount := 0
	if list != nil && len(list) > 0 {
		for _, key := range list {
			if *key.Status == iam.StatusTypeInactive {
				log.Infof("Deleting inactive key: %s", *key.AccessKeyId)
				deleteKey(ctx, key.AccessKeyId, userName)
			} else {
				keyCount++
			}
		}
	}
	if keyCount == len(list) {
		log.Info("No inactive keys found")
	}
	return nil
}

func cleanupOldSecrets(ctx *context.Context, secretID *string, userName *string) error {
	accessKey, err := getSecret(ctx, secretID, aws.String(StagePrevious))
	if err != nil {
		return err
	}

	// Make sure old key still exists
	list, err := listAccessKeys(ctx, userName)
	if err != nil {
		return err
	}
	found := false
	if list != nil && len(list) > 0 {
		for _, key := range list {
			if *key.AccessKeyId == accessKey.Key {
				found = true
			}
		}
	}
	if found == false {
		log.Info("Previous key has already been deleted")
		return nil
	}

	lastAccessed, err := getKeyLastAccess(ctx, &accessKey.Key)
	if err != nil {
		return err
	}

	if lastAccessed.LastUsedDate != nil {
		now := time.Now()
		diff := int(now.Sub(*lastAccessed.LastUsedDate).Seconds())
		log.Infof("Key last used %d seconds ago", diff)

		if diff < InactivitySeconds {
			log.Info("Key has been used recently. Leaving active for now")
			return nil
		}
	} else {
		log.Info("Key never used")
	}

	err = updateKeyStatus(ctx, &accessKey.Key, userName, aws.String(iam.StatusTypeInactive))
	if err != nil {
		return err
	}
	log.Info(fmt.Sprintf("Marked key %s inactive", accessKey.Key))

	return nil
}

func getSecret(ctx *context.Context, secretID *string, stage *string) (*AccessKeySecret, error) {
	secret, err := secretsSess.GetSecretValueWithContext(*ctx, &secretsmanager.GetSecretValueInput{
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

func listAccessKeys(ctx *context.Context, userName *string) ([]*iam.AccessKeyMetadata, error) {
	result, err := iamSess.ListAccessKeysWithContext(*ctx, &iam.ListAccessKeysInput{
		UserName: userName,
	})
	if err != nil {
		return nil, err
	}

	return result.AccessKeyMetadata, nil
}

func deleteKey(ctx *context.Context, accessKeyID *string, userName *string) error {
	_, err := iamSess.DeleteAccessKeyWithContext(*ctx, &iam.DeleteAccessKeyInput{
		AccessKeyId: accessKeyID,
		UserName:    userName,
	})

	if err != nil {
		return err
	}

	return nil
}

func updateKeyStatus(ctx *context.Context, accessKeyID *string, userName *string, status *string) error {
	_, err := iamSess.UpdateAccessKeyWithContext(*ctx, &iam.UpdateAccessKeyInput{
		AccessKeyId: accessKeyID,
		UserName:    userName,
		Status:      status,
	})

	if err != nil {
		return err
	}

	return nil
}

func getKeyLastAccess(ctx *context.Context, accessKeyID *string) (*iam.AccessKeyLastUsed, error) {
	result, err := iamSess.GetAccessKeyLastUsedWithContext(*ctx, &iam.GetAccessKeyLastUsedInput{
		AccessKeyId: accessKeyID,
	})

	if err != nil {
		return nil, err
	}

	return result.AccessKeyLastUsed, nil
}

func main() {
	lambda.Start(Handler)
}
