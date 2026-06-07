# ---- Etapa 1: Build ----
FROM golang:1.26-alpine AS builder

WORKDIR /app

# Copiar todo el proyecto incluyendo la carpeta vendor/
COPY . .

# Compilar usando las dependencias locales (vendor/)
RUN CGO_ENABLED=0 GOOS=linux go build -mod=vendor -o server ./cmd/main.go

# ---- Etapa 2: Imagen final (mínima) ----
FROM alpine:3.19

WORKDIR /app

COPY --from=builder /app/server .

RUN mkdir -p /app/uploads

EXPOSE 8080

CMD ["./server"]
