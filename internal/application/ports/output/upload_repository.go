package output

import "sistema_contable/internal/domain"

type UploadRepository interface {
	Save(upload domain.Upload) error
}
