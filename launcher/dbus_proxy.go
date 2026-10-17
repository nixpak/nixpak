package main

import (
	"os"
	"os/exec"
)

type Dbus struct {
	Cmd      *exec.Cmd
	SyncRead *os.File
}

func StartDbusproxy(conf Config) (dbus Dbus) {
	failed := true

	dbusproxyArgs := append([]string{"--fd=3"}, *conf.DbusProxy.Args...)

	cmd := exec.Command(*conf.DbusProxy.Exe, dbusproxyArgs...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	dbusSyncRead, dbusSyncWrite, err := os.Pipe()
	if err != nil {
		panic(err)
	}
	defer func() {
		if failed {
			dbusSyncRead.Close()
			dbusSyncWrite.Close()
		}
	}()
	cmd.ExtraFiles = []*os.File{dbusSyncWrite}

	dbus.Cmd = cmd
	dbus.SyncRead = dbusSyncRead

	if err := cmd.Start(); err != nil {
		panic(err)
	}
	defer func() {
		if failed {
			dbus.Close()
		}
	}()

	if err := dbusSyncWrite.Close(); err != nil {
		panic(err)
	}

	failed = false
	return
}

func (dbus *Dbus) WaitUntilStartup() {
	if _, err := dbus.SyncRead.Read([]byte{'x'}); err != nil {
		panic(err)
	}
}

func (dbus *Dbus) Close() {
	dbus.SyncRead.Close()
	dbus.Cmd.Wait()
}
