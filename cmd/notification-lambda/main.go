package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/ses"
)

type NotificationPayload struct {
	Email   string `json:"email"`
	Subject string `json:"subject"`
	Message string `json:"message"`
}

type SNSWrapper struct {
	Message string `json:"Message"`
}

func handler(ctx context.Context, sqsEvent events.SQSEvent) error {
	for _, record := range sqsEvent.Records {
		log.Printf("📨 Procesando mensaje SQS: %s", record.MessageId)

		// El mensaje SNS viene envuelto en el Body del registro SQS
		var wrapper SNSWrapper
		if err := json.Unmarshal([]byte(record.Body), &wrapper); err != nil {
			log.Printf("❌ Error parseando wrapper SNS: %v", err)
			return err
		}

		// Dentro del wrapper está el payload real
		var payload NotificationPayload
		if err := json.Unmarshal([]byte(wrapper.Message), &payload); err != nil {
			log.Printf("❌ Error parseando payload: %v", err)
			return err
		}

		log.Printf("📧 Enviando correo a: %s | Asunto: %s", payload.Email, payload.Subject)

		// Crear sesión AWS
		region := os.Getenv("AWS_REGION")
		sess, err := session.NewSession(&aws.Config{
			Region: aws.String(region),
		})
		if err != nil {
			return fmt.Errorf("error creando sesión AWS: %w", err)
		}

		// Enviar correo con SES
		fromEmail := os.Getenv("FROM_EMAIL")
		svc := ses.New(sess)

		_, err = svc.SendEmail(&ses.SendEmailInput{
			Source: aws.String(fromEmail),
			Destination: &ses.Destination{
				ToAddresses: []*string{aws.String(payload.Email)},
			},
			Message: &ses.Message{
				Subject: &ses.Content{
					Data:    aws.String(payload.Subject),
					Charset: aws.String("UTF-8"),
				},
				Body: &ses.Body{
					Text: &ses.Content{
						Data:    aws.String(payload.Message),
						Charset: aws.String("UTF-8"),
					},
				},
			},
		})
		if err != nil {
			log.Printf("❌ Error enviando correo: %v", err)
			return err
		}

		log.Printf("✅ Correo enviado exitosamente a %s", payload.Email)
	}

	return nil
}

func main() {
	lambda.Start(handler)
}
