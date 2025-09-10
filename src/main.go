package main

import (
	"context"
	"encoding/json"
	"log"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

type Response struct {
	StatusCode int               `json:"statusCode"`
	Headers    map[string]string `json:"headers"`
	Body       string            `json:"body"`
}

func handler(ctx context.Context, request events.APIGatewayProxyRequest) (Response, error) {
	log.Printf("Received request: %+v", request)

	responseBody := map[string]interface{}{
		"message": "Hello from Go Lambda!",
		"method":  request.HTTPMethod,
		"path":    request.Path,
		"headers": request.Headers,
	}

	if request.Body != "" {
		responseBody["body"] = request.Body
	}

	if len(request.QueryStringParameters) > 0 {
		responseBody["queryParams"] = request.QueryStringParameters
	}

	body, err := json.Marshal(responseBody)
	if err != nil {
		log.Printf("Error marshaling response: %v", err)
		return Response{
			StatusCode: 500,
			Headers: map[string]string{
				"Content-Type": "application/json",
			},
			Body: `{"error": "Internal server error"}`,
		}, nil
	}

	return Response{
		StatusCode: 200,
		Headers: map[string]string{
			"Content-Type":                 "application/json",
			"Access-Control-Allow-Origin":  "*",
			"Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
			"Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
		},
		Body: string(body),
	}, nil
}

func main() {
	lambda.Start(handler)
}
