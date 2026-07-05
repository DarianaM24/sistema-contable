package main

import (
	"context"
	"encoding/json"
	"log"

	"github.com/aws/aws-lambda-go/lambda"
)

// HeartbeatPayload es el mensaje que envía EventBridge Scheduler (via SNS/SQS
// o de forma directa) para confirmar que la tarea programada se ejecutó.
type HeartbeatPayload struct {
	Origen  string `json:"origen"`
	Mensaje string `json:"mensaje"`
	Tipo    string `json:"tipo"`
}

// handler recibe el evento sin procesar (puede venir envuelto por SNS/SQS o
// directo desde EventBridge Scheduler) y simplemente registra el evento en
// CloudWatch Logs. No envía correos ni interactúa con ningún otro servicio.
func handler(ctx context.Context, rawEvent json.RawMessage) error {
	log.Printf("💓 Heartbeat recibido - evento crudo: %s", string(rawEvent))

	var payload HeartbeatPayload
	if err := json.Unmarshal(rawEvent, &payload); err == nil && payload.Tipo != "" {
		log.Printf("✅ Heartbeat procesado | origen=%s | tipo=%s | mensaje=%s",
			payload.Origen, payload.Tipo, payload.Mensaje)
	} else {
		log.Printf("✅ Heartbeat procesado (formato no reconocido, se registra igualmente)")
	}

	return nil
}

func main() {
	lambda.Start(handler)
}
