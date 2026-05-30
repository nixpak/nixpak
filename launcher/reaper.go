package main

import (
	"os"
	"os/signal"

	"golang.org/x/sys/unix"
)

type ChildReaper struct {
	Signals chan os.Signal
}

func StartChildReaper() (reaper ChildReaper) {
	if err := unix.Prctl(unix.PR_SET_CHILD_SUBREAPER, uintptr(1), 0, 0, 0); err != nil {
		panic(err)
	}

	reaper.Signals = make(chan os.Signal, 1)
	reaper.Open()

	go func() {
		for {
			<-reaper.Signals
			for reaper.ReapChild(false) {
			}
		}
	}()

	return
}

func (reaper *ChildReaper) Open() {
	signal.Notify(reaper.Signals, unix.SIGCHLD)
}

func (reaper *ChildReaper) ReapChild(wait bool) bool {
	options := 0
	if !wait {
		options = unix.WNOHANG
	}

	for {
		var status unix.WaitStatus
		var err error
		pid, err := unix.Wait4(-1, &status, options, nil)
		switch err {
		case nil:
			return pid > 0
		case unix.ECHILD:
			return false
		case unix.EINTR:
			continue
		default:
			panic(err)
		}
	}
}

func (reaper *ChildReaper) WaitAndReapAllChildren() {
	reaper.Close()
	for reaper.ReapChild(true) {
	}
	reaper.Open()
}

func (reaper *ChildReaper) Close() {
	signal.Stop(reaper.Signals)
}
