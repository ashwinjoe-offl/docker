package main

import (
	"fmt"
	"log"
	"net/http"
)

func main() {
	http.HandleFunc("/", func(writer http.ResponseWriter, request *http.Request) {
		fmt.Fprint(writer, "Hello from CI/CD test!")
	})
	log.Fatal(http.ListenAndServe(":8080", nil))
}
