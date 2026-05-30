package main

import (
	"os"
	"os/exec"
	"strconv"
)

func StartPasta(conf Config, pid int) {
	pastaArgs := append(conf.PastaArgs, "--")
	pastaArgs = append(pastaArgs, strconv.Itoa(pid))

	pasta := exec.Command(conf.PastaExe, pastaArgs...)
	pasta.Stdout = os.Stdout
	pasta.Stderr = os.Stderr

	if err := pasta.Run(); err != nil {
		panic(err)
	}
}
