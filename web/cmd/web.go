package main

import (
	"embed"
	"encoding/json"
	"flag"
	"fmt"
	"io/fs"
	"log"
	"net/http"
	"os/exec"
	"strings"

	"gopkg.in/ini.v1"
)

//go:embed static
var staticFS embed.FS

type ConfigFile struct {
	ID      string
	Name    string
	Path    string
	Service string
}

type KeyValue struct {
	Key   string `json:"key"`
	Value string `json:"value"`
}

type Section struct {
	Name string     `json:"name"`
	Keys []KeyValue `json:"keys"`
}

type ConfigResponse struct {
	ID       string    `json:"id"`
	Name     string    `json:"name"`
	Path     string    `json:"path"`
	Service  string    `json:"service"`
	Sections []Section `json:"sections"`
}

var configFiles []ConfigFile

func findConfigFile(id string) *ConfigFile {
	for i := range configFiles {
		if configFiles[i].ID == id {
			return &configFiles[i]
		}
	}
	return nil
}

func readConfig(cf ConfigFile) (ConfigResponse, error) {
	resp := ConfigResponse{ID: cf.ID, Name: cf.Name, Path: cf.Path, Service: cf.Service}

	iniCfg, err := ini.Load(cf.Path)
	if err != nil {
		return resp, err
	}

	for _, sec := range iniCfg.Sections() {
		if sec.Name() == ini.DefaultSection && len(sec.Keys()) == 0 {
			continue
		}
		section := Section{Name: sec.Name()}
		for _, key := range sec.Keys() {
			section.Keys = append(section.Keys, KeyValue{Key: key.Name(), Value: key.Value()})
		}
		resp.Sections = append(resp.Sections, section)
	}

	return resp, nil
}

func writeConfig(cf ConfigFile, sections []Section) error {
	iniCfg, err := ini.Load(cf.Path)
	if err != nil {
		return err
	}

	for _, section := range sections {
		sec, err := iniCfg.GetSection(section.Name)
		if err != nil {
			sec, err = iniCfg.NewSection(section.Name)
			if err != nil {
				return err
			}
		}
		for _, kv := range section.Keys {
			sec.Key(kv.Key).SetValue(kv.Value)
		}
	}

	return iniCfg.SaveTo(cf.Path)
}

func handleConfigs(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	responses := make([]ConfigResponse, 0, len(configFiles))
	for _, cf := range configFiles {
		resp, err := readConfig(cf)
		if err != nil {
			http.Error(w, fmt.Sprintf("failed to read %s: %v", cf.Path, err), http.StatusInternalServerError)
			return
		}
		responses = append(responses, resp)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(responses)
}

func handleConfigSave(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	id := strings.TrimPrefix(r.URL.Path, "/api/configs/")
	cf := findConfigFile(id)
	if cf == nil {
		http.Error(w, "unknown config id", http.StatusNotFound)
		return
	}

	var body struct {
		Sections []Section `json:"sections"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, fmt.Sprintf("invalid request body: %v", err), http.StatusBadRequest)
		return
	}

	if err := writeConfig(*cf, body.Sections); err != nil {
		http.Error(w, fmt.Sprintf("failed to save %s: %v", cf.Path, err), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func handleRestart(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	id := strings.TrimPrefix(r.URL.Path, "/api/restart/")
	cf := findConfigFile(id)
	if cf == nil {
		http.Error(w, "unknown config id", http.StatusNotFound)
		return
	}

	cmd := exec.Command("systemctl", "restart", cf.Service)
	if out, err := cmd.CombinedOutput(); err != nil {
		http.Error(w, fmt.Sprintf("failed to restart %s: %v: %s", cf.Service, err, out), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func main() {
	listen := flag.String("listen", ":8080", "адрес и порт для веб-интерфейса")
	mmdvmhostConfig := flag.String("mmdvmhost-config", "/etc/MMDVMHost/mmdvmhost.cfg", "путь к mmdvmhost.cfg")
	dmrgatewayConfig := flag.String("dmrgateway-config", "/etc/DMRGateway/dmrgateway.cfg", "путь к dmrgateway.cfg")
	flag.Parse()

	ini.PrettyFormat = false

	configFiles = []ConfigFile{
		{ID: "mmdvmhost", Name: "MMDVMHost", Path: *mmdvmhostConfig, Service: "mmdvmhost.service"},
		{ID: "dmrgateway", Name: "DMRGateway", Path: *dmrgatewayConfig, Service: "dmrgateway.service"},
	}

	staticContent, err := fs.Sub(staticFS, "static")
	if err != nil {
		log.Fatal(err)
	}

	mux := http.NewServeMux()
	mux.Handle("/", http.FileServer(http.FS(staticContent)))
	mux.HandleFunc("/api/configs", handleConfigs)
	mux.HandleFunc("/api/configs/", handleConfigSave)
	mux.HandleFunc("/api/restart/", handleRestart)

	log.Printf("repka-web слушает на %s", *listen)
	log.Fatal(http.ListenAndServe(*listen, mux))
}
