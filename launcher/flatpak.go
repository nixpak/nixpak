package main

import (
	"io"
	"os"
)

type FlatpakMetadata struct {
	InfoFileTemplate  string
	MetadataDirectory string
}

func (f *FlatpakMetadata) Setup() {
	err := os.MkdirAll(f.MetadataDirectory, 0700)
	if err != nil {
		panic(err)
	}
	src, err := os.Open(f.InfoFileTemplate)
	if err != nil {
		panic(err)
	}
	defer src.Close()
	dst, err := os.Create(f.MetadataDirectory + "/info")
	if err != nil {
		panic(err)
	}
	defer dst.Close()
	_, err = io.Copy(dst, src)
	if err != nil {
		panic(err)
	}
	_, err = dst.Write([]byte("\n\n[Instance]\ninstance-id=nixpak-app-" + instanceId() + "\n"))
	if err != nil {
		panic(err)
	}
	// horrible hack
	os.Setenv("FLATPAK_METADATA_FILE", f.MetadataDirectory+"/info")
}

func (f *FlatpakMetadata) WriteBwrapInfo(infoJson []byte) {
	file, err := os.Create(f.MetadataDirectory + "/bwrapinfo.json")
	if err != nil {
		panic(err)
	}
	defer file.Close()
	_, err = file.Write(infoJson)
	if err != nil {
		panic(err)
	}
}

func (f *FlatpakMetadata) Cleanup() {
	os.RemoveAll(f.MetadataDirectory)
}
