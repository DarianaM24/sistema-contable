package repository

import (
	"database/sql"

	"sistema_contable/internal/domain"
)

type UserRepository struct {
	db *sql.DB
}

func NewUserRepository(db *sql.DB) *UserRepository {
	return &UserRepository{
		db: db,
	}
}

// Crear usuario
func (r *UserRepository) Create(user domain.User) error {

	_, err := r.db.Exec(
		"INSERT INTO users (name, email, password) VALUES ($1, $2, $3)",
		user.Name,
		user.Email,
		user.Password,
	)

	return err
}

// Obtener todos los usuarios
func (r *UserRepository) FindAll() ([]domain.User, error) {

	rows, err := r.db.Query(
		"SELECT id, name, email, password FROM users",
	)

	if err != nil {
		return nil, err
	}

	defer rows.Close()

	var users []domain.User

	for rows.Next() {

		var user domain.User

		err := rows.Scan(
			&user.ID,
			&user.Name,
			&user.Email,
			&user.Password,
		)

		if err != nil {
			return nil, err
		}

		users = append(users, user)
	}

	return users, nil
}

// Buscar usuario por ID
func (r *UserRepository) FindByID(id uint) (*domain.User, error) {

	var user domain.User

	err := r.db.QueryRow(
		"SELECT id, name, email, password FROM users WHERE id = $1",
		id,
	).Scan(
		&user.ID,
		&user.Name,
		&user.Email,
		&user.Password,
	)

	if err != nil {
		return nil, err
	}

	return &user, nil
}

// Buscar usuario por email
func (r *UserRepository) FindByEmail(email string) (*domain.User, error) {

	var user domain.User

	err := r.db.QueryRow(
		"SELECT id, name, email, password FROM users WHERE email = $1",
		email,
	).Scan(
		&user.ID,
		&user.Name,
		&user.Email,
		&user.Password,
	)

	if err != nil {
		return nil, err
	}

	return &user, nil
}

// Actualizar usuario
func (r *UserRepository) Update(user domain.User) error {

	_, err := r.db.Exec(
		"UPDATE users SET name=$1, email=$2, password=$3 WHERE id=$4",
		user.Name,
		user.Email,
		user.Password,
		user.ID,
	)

	return err
}

// Eliminar usuario
func (r *UserRepository) Delete(id uint) error {

	_, err := r.db.Exec(
		"DELETE FROM users WHERE id = $1",
		id,
	)

	return err
}
