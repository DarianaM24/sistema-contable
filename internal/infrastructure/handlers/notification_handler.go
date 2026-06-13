package handlers

import (
	"fmt"
	"net/http"
	"os"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/sns"
	"github.com/gin-gonic/gin"
)

type NotificationHandler struct{}

func NewNotificationHandler() *NotificationHandler {
	return &NotificationHandler{}
}

type NotificationRequest struct {
	Email   string `json:"email"   binding:"required"`
	Subject string `json:"subject" binding:"required"`
	Message string `json:"message" binding:"required"`
}

// POST /notifications/send
func (h *NotificationHandler) SendNotification(c *gin.Context) {
	var req NotificationRequest

	// 1. Validar el body
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "email, subject y message son requeridos",
		})
		return
	}

	// 2. Crear sesión AWS
	region := os.Getenv("S3_REGION")
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Error al crear sesión de AWS",
		})
		return
	}

	// 3. Publicar en SNS
	topicArn := os.Getenv("SNS_TOPIC_ARN")
	svc := sns.New(sess)

	message := fmt.Sprintf(`{"email":"%s","subject":"%s","message":"%s"}`,
		req.Email, req.Subject, req.Message)

	_, err = svc.Publish(&sns.PublishInput{
		TopicArn: aws.String(topicArn),
		Message:  aws.String(message),
		Subject:  aws.String(req.Subject),
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Error al enviar mensaje",
		})
		return
	}

	// 4. Respuesta exitosa
	c.JSON(http.StatusOK, gin.H{
		"message": "Mensaje enviado correctamente",
	})
}
