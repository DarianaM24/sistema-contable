package domain

import "time"

type Upload struct {
	ID        uint      `json:"id"`
	FileName  string    `json:"file_name"`
	FileURL   string    `json:"file_url"`
	FileSize  int64     `json:"file_size"`
	CreatedAt time.Time `json:"created_at"`
}
