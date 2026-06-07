package repository

import (
	"database/sql"
	"sistema_contable/internal/domain"
)

type UploadRepository struct {
	db *sql.DB
}

func NewUploadRepository(db *sql.DB) *UploadRepository {
	return &UploadRepository{db: db}
}

func (r *UploadRepository) Save(upload domain.Upload) error {
	_, err := r.db.Exec(
		"INSERT INTO uploads (file_name, file_url, file_size) VALUES ($1, $2, $3)",
		upload.FileName,
		upload.FileURL,
		upload.FileSize,
	)
	return err
}
