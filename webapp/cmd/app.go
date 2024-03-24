package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func handler(w http.ResponseWriter, r *http.Request) {
	file, _ := os.ReadFile("/home/ivan/sources/repka-star/mmdvmhost.service")
	fmt.Fprint(w, string(file))
}

func main() {
	http.HandleFunc("/", handler)
	log.Fatal(http.ListenAndServe(":8085", nil))
}
