package main

import (
	"os"
	"os/exec"
	"strconv"
)

func StartPasta(conf Config, pid int) {
	pastaArgs := append(*conf.Pasta.Args, "--")
	pastaArgs = append(pastaArgs, strconv.Itoa(pid))

	pasta := exec.Command(*conf.Pasta.Exe, pastaArgs...)
	pasta.Stdout = os.Stdout
	pasta.Stderr = os.Stderr

	if err := pasta.Run(); err != nil {
		panic(err)
	}
}
