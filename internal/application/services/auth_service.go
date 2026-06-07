package services

import (
	"errors"
	"sistema_contable/internal/application/ports/output"
	"sistema_contable/internal/infrastructure/security"

	"golang.org/x/crypto/bcrypt"
)

type AuthService struct {
	repo       output.UserRepository
	jwtService *security.JWTService
}

func NewAuthService(repo output.UserRepository, jwt *security.JWTService) *AuthService {
	return &AuthService{
		repo:       repo,
		jwtService: jwt,
	}
}

func (s *AuthService) Login(email, password string) (string, error) {

	user, err := s.repo.FindByEmail(email)
	if err != nil {
		return "", errors.New("user not found")
	}

	err = bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(password))
	if err != nil {
		return "", errors.New("invalid password")
	}

	token, err := s.jwtService.GenerateToken(user.ID)
	if err != nil {
		return "", err
	}

	return token, nil
}
