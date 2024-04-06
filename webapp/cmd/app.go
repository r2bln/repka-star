package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"

	"gopkg.in/ini.v1"
	"gopkg.in/yaml.v2"
)

type Cfg struct {
	Webapp struct {
		Port                 string `yaml:"port"`
		MmdvmhostConfigPath  string `yaml:"mmdvmhostConfigPath"`
		DmrgatewayConfigPath string `yaml:"dmrgatewayConfigPath"`
		Static               string `yaml:"static"`
	}
}

var cfg Cfg

func response(w http.ResponseWriter, resp string) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Headers", "content-type")
	w.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS, PUT, DELETE")
	fmt.Fprint(w, resp)
}

func handler(w http.ResponseWriter, r *http.Request) {
	iniCfg, err := ini.Load(cfg.Webapp.MmdvmhostConfigPath)

	if err != nil {
		fmt.Printf("Fail to read file: %v", err)
		os.Exit(1)
	}

	pathParts := strings.Split(r.URL.Path, "/")

	section, err := iniCfg.GetSection(pathParts[2])
	if err != nil {
		response(w, fmt.Sprintf("No section %s", pathParts[2]))
		return
	}

	data := []map[string]any{}

	switch r.Method {
	case "PUT":
		body, err := io.ReadAll(r.Body)
		if err != nil {
			log.Fatalln(err)
		}

		err = json.Unmarshal(body, &data)
		if err != nil {
			os.Exit(1)
		}

		for _, el := range data {
			fmt.Printf("%s: %s\r\n", el["key"], el["value"])
			key := el["key"].(string)
			value := el["value"].(string)
			section.Key(key).SetValue(value)
		}

		iniCfg.SaveTo(cfg.Webapp.MmdvmhostConfigPath)
		response(w, "saved")
	default:
		for key, val := range section.KeysHash() {
			fmt.Printf("%s - %s\r\n", key, val)
			data = append(data, map[string]any{"key": key, "value": val})
		}

		js, err := json.Marshal(data)
		if err != nil {
			os.Exit(1)
		}
		response(w, string(js))
	}
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
