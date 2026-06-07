package handlers

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"sistema_contable/internal/application/ports/output"
	"sistema_contable/internal/domain"
	"time"

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

	// Obtener el archivo del form-data (campo "file")
	file, header, err := c.Request.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "No se encontró el archivo (campo esperado: 'file')",
		})
		return
	}
	defer file.Close()

	// Crear carpeta uploads/ si no existe
	uploadDir := "./uploads"
	if err := os.MkdirAll(uploadDir, os.ModePerm); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "No se pudo crear el directorio de uploads",
		})
		return
	}

	// Nombre único: timestamp + extensión original
	ext := filepath.Ext(header.Filename)
	fileName := fmt.Sprintf("%d%s", time.Now().UnixMilli(), ext)
	filePath := filepath.Join(uploadDir, fileName)

	// Guardar archivo en disco
	if err := c.SaveUploadedFile(header, filePath); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "No se pudo guardar el archivo",
		})
		return
	}

	fileURL := fmt.Sprintf("/uploads/%s", fileName)

	// 💾 Guardar referencia en base de datos
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
