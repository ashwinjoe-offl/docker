package main

import (
	"fmt"
	"log"
	"net/http"
	"time"
)

func main() {
	http.HandleFunc("/", func(writer http.ResponseWriter, request *http.Request) {
		fmt.Fprintf(writer, "� PIPELINE SUCCESS! v3.0 - This message was deployed through CI/CD at: %s", time.Now().Format(time.RFC3339))
	})
	log.Fatal(http.ListenAndServe(":8080", nil))
}
