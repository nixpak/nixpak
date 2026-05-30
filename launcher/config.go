package main

import (
	"os"
	"path/filepath"
)

type Config struct {
	AppExe                  string
	AppArgs                 []string
	BwrapExe                string
	BwrapArgs               []string
	UseDbusProxy            bool
	DbusproxyExe            string
	DbusproxyArgs           []string
	UsePasta                bool
	PastaExe                string
	PastaArgs               []string
	UseFlatpakMetadata      bool
	FlatpakMetadataTemplate string
	UseWaylandProxy         bool
	WaylandProxyExe         string
	WaylandProxyArgs        []string
	WaylandProxySocketPath  string
}

func readConfig() (conf Config) {
	appExe, foundAppExe := os.LookupEnv("NIXPAK_APP_EXE")
	if !foundAppExe {
		panic("No executable given")
	}
	conf.AppExe = appExe
	conf.AppArgs = os.Args[1:]

	bwrapArgsJson, foundBwrapArgs := os.LookupEnv("BUBBLEWRAP_ARGS")
	if !foundBwrapArgs {
		panic("No bubblewrap args given")
	}
	conf.BwrapArgs = readJsonArgs(bwrapArgsJson)
	conf.BwrapExe = envOr("BWRAP_EXE", "bwrap")

	dbusproxyArgsJson, useDbusProxy := os.LookupEnv("XDG_DBUS_PROXY_ARGS")
	conf.UseDbusProxy = useDbusProxy
	if useDbusProxy {
		conf.DbusproxyArgs = readJsonArgs(dbusproxyArgsJson)
		conf.DbusproxyExe = envOr("XDG_DBUS_PROXY_EXE", "xdg-dbus-proxy")
	}

	pastaArgsJson, usePasta := os.LookupEnv("PASTA_ARGS")
	conf.UsePasta = usePasta
	if usePasta {
		conf.PastaArgs = readJsonArgs(pastaArgsJson)
		conf.PastaExe = envOr("PASTA_EXE", "pasta")
	}

	flatpakMetadataTemplate, useFlatpakMetadata := os.LookupEnv("FLATPAK_METADATA_TEMPLATE")
	conf.UseFlatpakMetadata = useFlatpakMetadata
	if useFlatpakMetadata {
		conf.FlatpakMetadataTemplate = flatpakMetadataTemplate
	}

	waylandProxyArgsJson, useWaylandProxy := os.LookupEnv("WAYLAND_PROXY_ARGS")
	conf.UseWaylandProxy = useWaylandProxy
	if useWaylandProxy {
		conf.WaylandProxyArgs = readJsonArgs(waylandProxyArgsJson)
		conf.WaylandProxyExe = envOr("WAYLAND_PROXY_EXE", "wayland-proxy-virtwl")
		conf.WaylandProxySocketPath = filepath.Join(requiredEnv("XDG_RUNTIME_DIR"), "nixpak-wayland-"+instanceId())

		if _, err := os.Stat(conf.WaylandProxySocketPath); err == nil {
			panic("Wayland proxy socket already exists")
		}
	}

	return
}
