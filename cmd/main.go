package main

import (
	"os"
	"sistema_contable/internal/application/services"
	"sistema_contable/internal/infrastructure/database"
	"sistema_contable/internal/infrastructure/handlers"
	"sistema_contable/internal/infrastructure/middleware"
	"sistema_contable/internal/infrastructure/repository"
	"sistema_contable/internal/infrastructure/security"

	"github.com/aws/aws-lambda-go/lambda"
	ginadapter "github.com/awslabs/aws-lambda-go-api-proxy/gin"
	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

var ginLambda *ginadapter.GinLambdaV2

func init() {
	godotenv.Load()

	gin.SetMode(os.Getenv("GIN_MODE"))

	// 🔌 Conexión a DB
	DB := database.ConnectDB()

	router := gin.Default()

	// 🌐 CORS
	router.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"*"},
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: false,
	}))

	// 📦 Repositories
	userRepository := repository.NewUserRepository(DB)
	uploadRepository := repository.NewUploadRepository(DB)

	// 🔐 JWT Service
	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		jwtSecret = "mi_secreto_super_seguro"
	}
	jwtService := security.NewJWTService(jwtSecret, "sistema_contable")

	// ⚙️ Services
	userService := services.NewUserService(userRepository)
	authService := services.NewAuthService(userRepository, jwtService)

	// 🎮 Handlers
	userHandler := handlers.NewUserHandler(userService, authService)
	uploadHandler := handlers.NewUploadHandler(uploadRepository)

	// 🔓 Rutas públicas
	router.POST("/login", userHandler.Login)
	router.POST("/users", userHandler.CreateUser)

	// 🔒 Rutas protegidas con JWT
	auth := router.Group("/")
	auth.Use(middleware.JWTMiddleware())
	{
		auth.GET("/users", userHandler.GetUsers)
		auth.GET("/users/:id", userHandler.GetUserByID)
		auth.PUT("/users/:id", userHandler.UpdateUser)
		auth.DELETE("/users/:id", userHandler.DeleteUser)

		// 📤 Upload
		auth.POST("/upload", uploadHandler.UploadFile)
	}

	// Adapter Gin → Lambda
	ginLambda = ginadapter.NewV2(router)
}

func main() {
	lambda.Start(ginLambda.ProxyWithContext)
}
