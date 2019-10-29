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
	log "github.com/sirupsen/logrus"
)

var (
	sess    = session.Must(session.NewSession())
	secrets = secretsmanager.New(sess)
	iamSess = iam.New(sess)
)

const (
	StageCurrent  = "AWSCURRENT"
	StagePending  = "AWSPENDING"
	StagePrevious = "AWSPREVIOUS"

	InactivitySeconds = 86400 // 24 hours
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
	log.Info("Starting cleanup")

	secrets, err := listRotatableSecrets(&ctx)
	if err != nil {
		log.Infof("Error listing secret %s", err)
		return err
	}

	for _, secret := range secrets {
		accessKey, err := getSecret(&ctx, secret.Name, aws.String(StageCurrent))
		if err != nil {
			log.Infof("Error fetching secret %s %s: %s", StageCurrent, *secret.Name, err)
			continue
		}

		log.Infof("Cleaning up secrets for %s", *secret.Name)
		log.Infof("User %s", accessKey.UserName)

		err = cleanupInactiveKeys(&ctx, &accessKey.UserName)
		if err != nil {
			log.Infof("Error cleaning up inactive keys for %s: %s", accessKey.UserName, err)
			continue
		}

		err = cleanupOldSecrets(&ctx, secret.Name, &accessKey.UserName)
		if err != nil {
			log.Infof("Error cleaning previous secret keys for secret %s and user %s: %s", *secret.Name, accessKey.UserName, err)
			continue
		}
	}

	return nil
}

// Delete any keys marked inactive
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

func listRotatableSecrets(ctx *context.Context) ([]*secretsmanager.SecretListEntry, error) {
	result, err := secrets.ListSecretsWithContext(*ctx, &secretsmanager.ListSecretsInput{})
	if err != nil {
		log.Infof("Error listing secret %s", err)
		return nil, err
	}

	output := []*secretsmanager.SecretListEntry{}
	for _, secret := range result.SecretList {
		if secret.Tags == nil {
			continue
		}
		for _, tag := range secret.Tags {
			if *tag.Key == "Rotatable" && *tag.Value == "true" {
				output = append(output, secret)
				break
			}
		}
	}

	return output, nil
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
