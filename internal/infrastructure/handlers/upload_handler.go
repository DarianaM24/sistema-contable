package handlers

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"sistema_contable/internal/application/ports/output"
	"sistema_contable/internal/domain"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/gin-gonic/gin"
)

type UploadHandler struct {
	repo output.UploadRepository
}

func NewUploadHandler(repo output.UploadRepository) *UploadHandler {
	return &UploadHandler{repo: repo}
}

// POST /upload
func (h *UploadHandler) UploadFile(c *gin.Context) {

	file, header, err := c.Request.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "No se encontró el archivo (campo esperado: 'file')",
		})
		return
	}
	defer file.Close()

	// Nombre único: timestamp + extensión original
	ext := filepath.Ext(header.Filename)
	fileName := fmt.Sprintf("%d%s", time.Now().UnixMilli(), ext)

	// Subir a S3
	bucket := os.Getenv("S3_BUCKET")
	region := os.Getenv("S3_REGION")

	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "No se pudo crear sesión de AWS",
		})
		return
	}

	svc := s3.New(sess)
	_, err = svc.PutObject(&s3.PutObjectInput{
		Bucket:        aws.String(bucket),
		Key:           aws.String(fileName),
		Body:          file,
		ContentLength: aws.Int64(header.Size),
		ContentType:   aws.String(header.Header.Get("Content-Type")),
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": fmt.Sprintf("No se pudo subir el archivo a S3: %s", err.Error()),
		})
		return
	}

	fileURL := fmt.Sprintf("https://%s.s3.%s.amazonaws.com/%s", bucket, region, fileName)

	// Guardar referencia en base de datos
	upload := domain.Upload{
		FileName: fileName,
		FileURL:  fileURL,
		FileSize: header.Size,
	}

	if err := h.repo.Save(upload); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Archivo guardado pero no se pudo registrar en base de datos",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":   "Archivo subido y registrado correctamente",
		"file_name": fileName,
		"file_url":  fileURL,
		"file_size": header.Size,
	})
}
