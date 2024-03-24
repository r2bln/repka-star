package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"

	"gopkg.in/ini.v1"
)

func handler(w http.ResponseWriter, r *http.Request) {
	cfg, err := ini.Load("/home/ivan/sources/repka-star/mmdvmhost.cfg")

	if err != nil {
		fmt.Printf("Fail to read file: %v", err)
		os.Exit(1)
	}

	section, _ := cfg.GetSection(r.URL.Path[1:])

	data := map[string]any{}
	for key, val := range section.KeysHash() {
		fmt.Printf("%s - %s\r\n", key, val)
		data[key] = val
	}

	print(data)

	js, err := json.Marshal(data)

	if err != nil {
		os.Exit(1)
	}

	fmt.Fprint(w, string(js))
}

func main() {
	http.HandleFunc("/", handler)
	log.Fatal(http.ListenAndServe(":8085", nil))
}
