package main

import (
	"encoding/json"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"

	"golang.org/x/sys/unix"
)

type BwrapInfo struct {
	ChildPid int    `json:"child-pid"`
	Raw      []byte `json:"-"`
}

type Bwrap struct {
	Cmd        *exec.Cmd
	InfoRead   *os.File
	BlockWrite *os.File
	Info       BwrapInfo
}

func StartBwrap(conf Config, flatpakMetadata FlatpakMetadata) (bwrap Bwrap) {
	failed := true

	bwrapArgs := append([]string{"--info-fd", "3", "--block-fd", "4"}, conf.BwrapArgs...)
	if conf.UseFlatpakMetadata {
		bwrapArgs = append(bwrapArgs, []string{"--ro-bind", flatpakMetadata.MetadataDirectory + "/info", "/.flatpak-info"}...)
	}
	if conf.UseWaylandProxy {
		waylandProxySocketPathInner := filepath.Join(requiredEnv("XDG_RUNTIME_DIR"), "nixpak-wayland")
		bwrapArgs = append(bwrapArgs, "--bind", conf.WaylandProxySocketPath, waylandProxySocketPathInner)
		bwrapArgs = append(bwrapArgs, "--setenv", "WAYLAND_DISPLAY", "nixpak-wayland")
	}
	bwrapArgs = append(bwrapArgs, "--")
	bwrapArgs = append(bwrapArgs, conf.AppExe)
	bwrapArgs = append(bwrapArgs, conf.AppArgs...)

	cmd := exec.Command(conf.BwrapExe, bwrapArgs...)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	bwrapInfoRead, bwrapInfoWrite, err := os.Pipe()
	if err != nil {
		panic(err)
	}
	defer func() {
		if failed {
			bwrapInfoRead.Close()
			bwrapInfoWrite.Close()
		}
	}()
	bwrapBlockRead, bwrapBlockWrite, err := os.Pipe()
	if err != nil {
		panic(err)
	}
	defer func() {
		if failed {
			bwrapBlockRead.Close()
			bwrapBlockWrite.Close()
		}
	}()
	cmd.ExtraFiles = []*os.File{bwrapInfoWrite, bwrapBlockRead}

	bwrap.Cmd = cmd
	bwrap.InfoRead = bwrapInfoRead
	bwrap.BlockWrite = bwrapBlockWrite

	if err := cmd.Start(); err != nil {
		panic(err)
	}
	defer func() {
		if failed {
			bwrap.Close()
		}
	}()

	if err := bwrapInfoWrite.Close(); err != nil {
		panic(err)
	}
	if err := bwrapBlockRead.Close(); err != nil {
		panic(err)
	}

	failed = false
	return
}

func (bwrap *Bwrap) WaitUntilSandboxReady() (bwrapInfo BwrapInfo) {
	if bytes, err := io.ReadAll(bwrap.InfoRead); err == nil {
		if err := json.Unmarshal(bytes, &bwrapInfo); err != nil {
			panic(err)
		}
		if bwrapInfo.ChildPid <= 0 {
			panic("Unexpected child PID")
		}
		bwrapInfo.Raw = bytes
		bwrap.Info = bwrapInfo
	} else {
		panic(err)
	}
	if err := bwrap.InfoRead.Close(); err != nil {
		panic(err)
	}

	return
}

func (bwrap *Bwrap) NotifySandboxFinished() {
	if _, err := bwrap.BlockWrite.Write([]byte{'x'}); err != nil {
		panic(err)
	}
	if err := bwrap.BlockWrite.Close(); err != nil {
		panic(err)
	}
}

func (bwrap *Bwrap) WaitUntilParentExit() error {
	return bwrap.Cmd.Wait()
}

func (bwrap *Bwrap) KillAndWaitUntilChildExit(kill bool) {
	bwrapChild, err := os.FindProcess(bwrap.Info.ChildPid)
	if err != nil {
		panic(err)
	}
	if kill {
		bwrapChild.Kill()
	}
	if _, err := bwrapChild.Wait(); err != nil {
		syscallErr, ok := err.(*os.SyscallError)
		if !ok || syscallErr.Unwrap() != unix.ECHILD {
			panic(err)
		}
	}
}

func (bwrap *Bwrap) WaitUntilChildExit() {
	bwrap.KillAndWaitUntilChildExit(false)
}

func (bwrap *Bwrap) CloseChild() {
	bwrap.KillAndWaitUntilChildExit(true)
}

func (bwrap *Bwrap) Close() {
	bwrap.Cmd.Process.Signal(syscall.SIGTERM)
	bwrap.Cmd.Wait()
	bwrap.BlockWrite.Close()
	bwrap.InfoRead.Close()
}
