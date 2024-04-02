package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"

	"gopkg.in/ini.v1"
	"gopkg.in/yaml.v2"
)

type Cfg struct {
	Webapp struct {
		Port   string `yaml: "port"`
		Path   string `yaml: "path"`
		Static string `yaml: "static"`
	}
}

var cfg Cfg

func handler(w http.ResponseWriter, r *http.Request) {
	cfg, err := ini.Load(cfg.Webapp.Path + "mmdvmhost.cfg")

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
	data, err := os.ReadFile(os.Args[1])

	if err != nil {
		log.Fatalf("Could not open file %s", os.Args[1])
	}

	err = yaml.Unmarshal(data, &cfg)

	if err != nil {
		log.Fatalf("Could not parse %s", os.Args[1])
	}

	fs := http.FileServer(http.Dir(cfg.Webapp.Static))
	http.Handle("/", fs)
	http.HandleFunc("/api/", handler)
	log.Fatal(http.ListenAndServe(":"+cfg.Webapp.Port, nil))
}
