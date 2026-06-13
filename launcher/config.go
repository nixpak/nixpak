package main

import (
	"encoding/json"
	"io"
	"os"
	"strings"
)

type ToolConfig struct {
	Exe  string
	Args SlothList
}

type OptionalToolConfig struct {
	Enable bool
	Exe    *string
	Args   *SlothList
}

type FlatpakConfig struct {
	MetadataTemplate string
}

type Config struct {
	AppExe       string
	AppArgs      []string
	Bwrap        ToolConfig         `json:"bwrap"`
	Flatpak      FlatpakConfig      `json:"flatpak"`
	DbusProxy    OptionalToolConfig `json:"dbusProxy"`
	Pasta        OptionalToolConfig `json:"pasta"`
	WaylandProxy OptionalToolConfig `json:"waylandProxy"`
}

func readConfig(path string, appArgs []string) (*Config, error) {
	toplevel, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer toplevel.Close()

	fileBytes, err := io.ReadAll(toplevel)
	if err != nil {
		return nil, err
	}

	lines := strings.Split(string(fileBytes), "\n")

	configFile, err := os.Open(lines[1])
	if err != nil {
		return nil, err
	}
	defer configFile.Close()

	dec := json.NewDecoder(configFile)
	conf := new(Config)
	if err := dec.Decode(conf); err != nil {
		return nil, err
	}

	conf.AppExe = lines[2]
	conf.AppArgs = appArgs
	return conf, nil
}
