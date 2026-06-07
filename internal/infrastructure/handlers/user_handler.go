package handlers

import (
	"net/http"
	"strconv"

	"sistema_contable/internal/application/services"
	"sistema_contable/internal/domain"

	"github.com/gin-gonic/gin"
)

type UserHandler struct {
	service     *services.UserService
	authService *services.AuthService
}

func NewUserHandler(service *services.UserService, auth *services.AuthService) *UserHandler {
	return &UserHandler{
		service:     service,
		authService: auth,
	}
}

// 🔐 LOGIN (placeholder listo para JWT)
func (h *UserHandler) Login(c *gin.Context) {

	var req struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"error": "invalid body"})
		return
	}

	token, err := h.authService.Login(req.Email, req.Password)
	if err != nil {
		c.JSON(401, gin.H{"error": err.Error()})
		return
	}

	c.JSON(200, gin.H{
		"token": token,
	})
}

// 🟢 CREATE USER
func (h *UserHandler) CreateUser(c *gin.Context) {

	var user domain.User

	if err := c.ShouldBindJSON(&user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": err.Error(),
		})
		return
	}

	err := h.service.CreateUser(user)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": err.Error(),
		})
		return
	}

	c.JSON(http.StatusCreated, user)
}

// 🟢 GET USERS
func (h *UserHandler) GetUsers(c *gin.Context) {

	users, err := h.service.GetUsers()

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, users)
}

// 🟢 GET USER BY ID
func (h *UserHandler) GetUserByID(c *gin.Context) {

	idParam := c.Param("id")

	id, _ := strconv.Atoi(idParam)

	user, err := h.service.GetUserByID(uint(id))

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "User not found",
		})
		return
	}

	c.JSON(http.StatusOK, user)
}

// 🟢 UPDATE USER
func (h *UserHandler) UpdateUser(c *gin.Context) {

	idParam := c.Param("id")

	id, _ := strconv.Atoi(idParam)

	var user domain.User

	if err := c.ShouldBindJSON(&user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": err.Error(),
		})
		return
	}

	user.ID = uint(id)

	err := h.service.UpdateUser(user)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, user)
}

// 🟢 DELETE USER
func (h *UserHandler) DeleteUser(c *gin.Context) {

	idParam := c.Param("id")

	id, _ := strconv.Atoi(idParam)

	err := h.service.DeleteUser(uint(id))

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "User deleted successfully",
	})
}
