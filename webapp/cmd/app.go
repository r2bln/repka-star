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

	section, _ := cfg.GetSection(r.URL.Path[5:])

	data := []map[string]any{}
	for key, val := range section.KeysHash() {
		fmt.Printf("%s - %s\r\n", key, val)
		data = append(data, map[string]any{"key": key, "value": val})
	}

	js, err := json.Marshal(data)

	if err != nil {
		os.Exit(1)
	}

	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS, PUT, DELETE")
	fmt.Fprint(w, string(js))
}

func main() {
	fs := http.FileServer(http.Dir("/home/ivan/sources/repka-star/webapp/web/repkastar/dist/"))
	http.Handle("/", fs)
	http.HandleFunc("/api/", handler)
	log.Fatal(http.ListenAndServe(":8085", nil))
}
