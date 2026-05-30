package main

import (
	"crypto/md5"
	"encoding/base32"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"

	"github.com/fsnotify/fsnotify"
)

func envOr(name string, or string) string {
	val, found := os.LookupEnv(name)
	if found {
		return val
	} else {
		return or
	}
}

func requiredEnv(name string) string {
	val, found := os.LookupEnv(name)
	if !found || val == "" {
		panic(fmt.Sprintf("environment variable '%s' not set", name))
	}
	return val
}

func instanceId() string {
	var sum = md5.Sum([]byte(strconv.Itoa(os.Getpid())))
	var enc = base32.NewEncoding("0123456789abcdfghijklmnpqrsvwxyz").WithPadding(base32.NoPadding)
	return enc.EncodeToString(sum[:])
}

func waitUntilFileAppears(filename string) {
	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		panic(err)
	}
	defer watcher.Close()

	if err := watcher.Add(filepath.Dir(filename)); err != nil {
		panic(err)
	}

	if _, err := os.Stat(filename); err == nil {
		return
	}

	for {
		select {
		case event := <-watcher.Events:
			if event.Name == filename && event.Op == fsnotify.Create {
				return
			}
		case err := <-watcher.Errors:
			panic(err)
		}
	}
}

func run() error {
	reaper := StartChildReaper()
	defer reaper.Close()
	defer reaper.WaitAndReapAllChildren()

	var flatpakMetadata FlatpakMetadata

	conf := readConfig()

	if conf.UseFlatpakMetadata {
		flatpakMetadata.InfoFileTemplate = conf.FlatpakMetadataTemplate
		flatpakMetadata.MetadataDirectory = os.Getenv("XDG_RUNTIME_DIR") + "/.flatpak/nixpak-app-" + instanceId()
		flatpakMetadata.Setup()
	}

	if conf.UseDbusProxy {
		dbus := StartDbusproxy(conf)
		defer dbus.Close()
		dbus.WaitUntilStartup()
	}

	if conf.UseWaylandProxy {
		waylandProxy := StartWaylandProxy(conf)
		defer waylandProxy.Close()
		waylandProxy.WaitUntilStartup()
	}

	bwrap := StartBwrap(conf, flatpakMetadata)
	defer bwrap.Close()
	bwrapInfo := bwrap.WaitUntilSandboxReady()
	defer bwrap.CloseChild()

	if conf.UseFlatpakMetadata {
		flatpakMetadata.WriteBwrapInfo(bwrapInfo.Raw)
		defer flatpakMetadata.Cleanup()
	}

	if conf.UsePasta {
		StartPasta(conf, bwrapInfo.ChildPid)
	}

	bwrap.NotifySandboxFinished()
	if err := bwrap.WaitUntilParentExit(); err != nil {
		if exiterr, ok := err.(*exec.ExitError); ok {
			return exiterr
		} else {
			panic(err)
		}
	}

	bwrap.WaitUntilChildExit()

	return nil
}

func main() {
	if err := run(); err != nil {
		if exiterr, ok := err.(*exec.ExitError); ok {
			os.Exit(exiterr.ExitCode())
		} else {
			panic(err)
		}
	}
}
