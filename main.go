package main

import (
	"fmt"
	"log"
	"net/http"
	"time"
)

func main() {
	http.HandleFunc("/", func(writer http.ResponseWriter, request *http.Request) {
		fmt.Fprintf(writer, "🎯 CI/CD Test v2.0 - If you see this, the pipeline worked! Deployed at: %s", time.Now().Format(time.RFC3339))
	})
	log.Fatal(http.ListenAndServe(":8080", nil))
}
