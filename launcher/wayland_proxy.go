package main

import (
	"os"
	"os/exec"
	"syscall"
)

type WaylandProxy struct {
	Cmd        *exec.Cmd
	SocketPath string
}

func StartWaylandProxy(conf Config) (waylandProxy WaylandProxy) {
	failed := true

	waylandProxy.SocketPath = conf.WaylandProxySocketPath
	waylandProxyArgs := append([]string{"--wayland-display=" + waylandProxy.SocketPath}, conf.WaylandProxyArgs...)

	cmd := exec.Command(conf.WaylandProxyExe, waylandProxyArgs...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	waylandProxy.Cmd = cmd

	if err := cmd.Start(); err != nil {
		panic(err)
	}
	defer func() {
		if failed {
			waylandProxy.Close()
		}
	}()

	failed = false
	return
}

func (waylandProxy *WaylandProxy) WaitUntilStartup() {
	waitUntilFileAppears(waylandProxy.SocketPath)
}

func (waylandProxy *WaylandProxy) Close() {
	waylandProxy.Cmd.Process.Signal(syscall.SIGTERM)
	waylandProxy.Cmd.Wait()

	// Cleanup socket file if it still exists
	os.Remove(waylandProxy.SocketPath)
}
