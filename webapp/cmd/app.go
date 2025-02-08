package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/exec"
	"os/signal"

	"gopkg.in/ini.v1"
	"gopkg.in/yaml.v2"

	"github.com/go-telegram/bot"
	"github.com/go-telegram/bot/models"
)

type Cfg struct {
	Bot struct {
		MmdvmhostConfigPath  string `yaml:"mmdvmhostConfigPath"`
		DmrgatewayConfigPath string `yaml:"dmrgatewayConfigPath"`
		Token                string `yaml:"token"`
	}
}

var cfg Cfg

const MODE_BM = 1
const MODE_QRA = 2

func restartDaemon(serviceName string) {
	cmd := exec.Command("systemctl", "restart", serviceName)
	if err := cmd.Run(); err != nil {
		log.Fatalf("failed to restart service %s: %v", serviceName, err)
	}
}

func setMode(mode uint16) {
	iniCfg, err := ini.Load(cfg.Bot.DmrgatewayConfigPath)

	if err != nil {
		log.Fatalf("Fail to read file: %v", err)
	}

	switch mode {
	case MODE_BM:
		section, err := iniCfg.GetSection("XLX Network")
		if err != nil {
			log.Fatal(err)
		}
		section.Key("Enabled").SetValue("0")
		section, err = iniCfg.GetSection("DMR Network 1")
		if err != nil {
			log.Fatal(err)
		}
		section.Key("Enabled").SetValue("1")
		iniCfg.SaveTo(cfg.Bot.DmrgatewayConfigPath)
		restartDaemon("dmrgateway.service")
	case MODE_QRA:
		section, err := iniCfg.GetSection("XLX Network")
		if err != nil {
			log.Fatal(err)
		}
		section.Key("Enabled").SetValue("1")
		section, err = iniCfg.GetSection("DMR Network 1")
		if err != nil {
			log.Fatal(err)
		}
		section.Key("Enabled").SetValue("0")
		iniCfg.SaveTo(cfg.Bot.DmrgatewayConfigPath)
		restartDaemon("dmrgateway.service")
	default:
		log.Fatalf("unknown mode")
	}
}

func getMode() string {
	iniCfg, err := ini.Load(cfg.Bot.DmrgatewayConfigPath)

	if err != nil {
		log.Fatalf("Fail to read file: %v", err)
	}

	section, err := iniCfg.GetSection("XLX Network")
	if err != nil {
		log.Fatal(err)
	}
	xlx := section.Key("Enabled").Value() == "1"

	section, err = iniCfg.GetSection("DMR Network 1")
	if err != nil {
		log.Fatal(err)
	}
	bm := section.Key("Enabled").Value() == "1"

	return fmt.Sprintf("BrandMeister: %t, QRA: %t", bm, xlx)
}

func handler(ctx context.Context, b *bot.Bot, update *models.Update) {
	switch update.Message.Text {
	case "/status":
		reply := getMode()

		b.SendMessage(ctx, &bot.SendMessageParams{
			ChatID: update.Message.Chat.ID,
			Text:   reply,
		})
	case "/gobm":
		setMode(MODE_BM)
		b.SendMessage(ctx, &bot.SendMessageParams{
			ChatID: update.Message.Chat.ID,
			Text:   "switching to BrandMeister: " + getMode(),
		})
	case "/goqra":
		setMode(MODE_QRA)
		b.SendMessage(ctx, &bot.SendMessageParams{
			ChatID: update.Message.Chat.ID,
			Text:   "switching to QRA: " + getMode(),
		})
	default:
		b.SendMessage(ctx, &bot.SendMessageParams{
			ChatID: update.Message.Chat.ID,
			Text:   "unknown command",
		})
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

	ini.PrettyFormat = false

	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt)
	defer cancel()

	opts := []bot.Option{
		bot.WithDefaultHandler(handler),
	}

	b, err := bot.New(cfg.Bot.Token, opts...)
	if err != nil {
		panic(err)
	}

	b.Start(ctx)
}
