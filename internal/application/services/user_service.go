package services

import (
	"sistema_contable/internal/application/ports/output"
	"sistema_contable/internal/domain"

	"golang.org/x/crypto/bcrypt"
)

type UserService struct {
	repo output.UserRepository
}

func NewUserService(repo output.UserRepository) *UserService {
	return &UserService{
		repo: repo,
	}
}

// Crear usuario (con password encriptada)
func (s *UserService) CreateUser(user domain.User) error {

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(user.Password), 14)
	if err != nil {
		return err
	}

	user.Password = string(hashedPassword)

	return s.repo.Create(user)
}

// Obtener usuarios
func (s *UserService) GetUsers() ([]domain.User, error) {
	return s.repo.FindAll()
}

// Buscar usuario por ID
func (s *UserService) GetUserByID(id uint) (*domain.User, error) {
	return s.repo.FindByID(id)
}

// Actualizar usuario
func (s *UserService) UpdateUser(user domain.User) error {

	if user.Password != "" {
		// Si viene password nueva, hashearla
		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(user.Password), 14)
		if err != nil {
			return err
		}
		user.Password = string(hashedPassword)
	} else {
		// Si NO viene password, buscar la que ya tiene en la DB y conservarla
		existing, err := s.repo.FindByID(user.ID)
		if err != nil {
			return err
		}
		user.Password = existing.Password
	}

	return s.repo.Update(user)
}

// Eliminar usuario
func (s *UserService) DeleteUser(id uint) error {
	return s.repo.Delete(id)
}
