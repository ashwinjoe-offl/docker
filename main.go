package main

import (
	"fmt"
	"log"
	"net/http"
	"time"
)

func main() {
	http.HandleFunc("/", func(writer http.ResponseWriter, request *http.Request) {
		fmt.Fprintf(writer, "Hello! This change was deployed by CI/CD at %s", time.Now().Format(time.RFC3339))
	})
	log.Fatal(http.ListenAndServe(":8080", nil))
}
