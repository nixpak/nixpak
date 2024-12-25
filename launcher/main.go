package main

import (
	"crypto/md5"
	"encoding/base32"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"strconv"
	"syscall"
)

type JsonRaw = map[string]interface{}
type Thunk func() string

type EnvVar struct {
	Type string
	Key  string
	Or   Thunk
}

func NewEnvVar(raw JsonRaw) (e EnvVar) {
	e.Type = "env"
	e.Key = raw["key"].(string)
	if or, ok := raw["or"]; ok {
		e.Or = func() string {
			return valToString(or)
		}
	}
	return
}

func (e EnvVar) String() string {
	r, _ := os.LookupEnv(e.Key)
	if r != "" {
		return r
	}
	if e.Or != nil {
		return e.Or()
	}
	panic(fmt.Sprintf("environment variable '%s' not set", e.Key))
}

type Concat struct {
	Type string
	A    string
	B    string
}

func NewConcat(raw JsonRaw) (c Concat) {
	c.Type = "concat"
	c.A = valToString(raw["a"])
	c.B = valToString(raw["b"])
	return
}

func (c Concat) String() string {
	return c.A + c.B
}

type InstanceId struct {
	Type string
	Id   string
}

func NewInstanceId(raw JsonRaw) (i InstanceId) {
	i.Type = "instanceId"
	var sum = md5.Sum([]byte(strconv.Itoa(os.Getpid())))
	var enc = base32.NewEncoding("0123456789abcdfghijklmnpqrsvwxyz").WithPadding(base32.NoPadding)
	i.Id = enc.EncodeToString(sum[:])
	return
}

func (i InstanceId) String() string {
	return i.Id
}

type Uid struct {
	Type string
}

func NewUid(raw JsonRaw) (u Uid) {
	u.Type = "uid"
	return
}

func (u Uid) String() string {
	return strconv.Itoa(os.Getuid())
}

type Gid struct {
	Type string
}

func NewGid(raw JsonRaw) (u Gid) {
	u.Type = "gid"
	return
}

func (u Gid) String() string {
	return strconv.Itoa(os.Getgid())
}

type Mkdir struct {
	Type string
	Dir  string
}

func NewMkdir(raw JsonRaw) (m Mkdir) {
	m.Type = "mkdir"
	m.Dir = valToString(raw["dir"])
	return
}

func (m Mkdir) String() string {
	err := os.MkdirAll(m.Dir, 0700)
	if err != nil {
		fmt.Println(err)
	}
	return m.Dir
}

func envOr(name string, or string) string {
	val, found := os.LookupEnv(name)
	if found {
		return val
	} else {
		return or
	}
}

func valToString(item interface{}) (ret string) {
	ret, ok := item.(string)
	if ok {
		return
	} else {
		raw, _ := item.(JsonRaw)
		switch raw["type"] {
		case "env":
			ret = NewEnvVar(raw).String()
		case "concat":
			ret = NewConcat(raw).String()
		case "instanceId":
			ret = NewInstanceId(raw).String()
		case "uid":
			ret = NewUid(raw).String()
		case "gid":
			ret = NewGid(raw).String()
		case "mkdir":
			ret = NewMkdir(raw).String()
		default:
			panic("Unknown type: \"" + raw["type"].(string) + "\"")
		}
		return
	}
}

func readJsonArgs(filename string) (args []string) {
	file, _ := os.Open(filename)
	bytes, _ := ioutil.ReadAll(file)
	var argsRaw []interface{}

	json.Unmarshal(bytes, &argsRaw)
	for _, item := range argsRaw {
		args = append(args, valToString(item))
	}
	return
}

type BwrapInfo struct {
	ChildPid int `json:"child-pid"`
}

func run() error {
	bwrapExe := envOr("BWRAP_EXE", "bwrap")

	bwrapArgsJson, foundBwrapArgs := os.LookupEnv("BUBBLEWRAP_ARGS")
	if !foundBwrapArgs {
		panic("No bubblewrap args given")
	}
	dbusproxyArgsJson, useDbusProxy := os.LookupEnv("XDG_DBUS_PROXY_ARGS")
	pastaArgsJson, usePasta := os.LookupEnv("PASTA_ARGS")

	appExe, foundAppExe := os.LookupEnv("NIXPAK_APP_EXE")
	if !foundAppExe {
		panic("No executable given")
	}

	bwrapArgs := readJsonArgs(bwrapArgsJson)
	bwrapArgs = append([]string{"--info-fd", "3", "--block-fd", "4"}, bwrapArgs...)
	bwrapArgs = append(bwrapArgs, "--")
	bwrapArgs = append(bwrapArgs, appExe)
	bwrapArgs = append(bwrapArgs, os.Args[1:]...)

	if useDbusProxy {
		dbusproxyExe := envOr("XDG_DBUS_PROXY_EXE", "xdg-dbus-proxy")
		dbusproxyArgs := readJsonArgs(dbusproxyArgsJson)
		dbusproxyArgs = append([]string{"--fd=3"}, dbusproxyArgs...)

		dbus := exec.Command(dbusproxyExe, dbusproxyArgs...)
		dbus.Stdout = os.Stdout
		dbus.Stderr = os.Stderr

		dbusSyncRead, dbusSyncWrite, err := os.Pipe()
		if err != nil {
			panic(err)
		}
		defer dbusSyncRead.Close()
		defer dbusSyncWrite.Close()
		dbus.ExtraFiles = []*os.File{dbusSyncWrite}

		if err := dbus.Start(); err != nil {
			panic(err)
		}
		defer dbus.Wait()
		defer dbusSyncRead.Close()

		if err := dbusSyncWrite.Close(); err != nil {
			panic(err)
		}

		if _, err := dbusSyncRead.Read([]byte{'x'}); err != nil {
			panic(err)
		}
	}

	bwrap := exec.Command(bwrapExe, bwrapArgs...)
	bwrap.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	bwrap.Stdout = os.Stdout
	bwrap.Stderr = os.Stderr

	bwrapInfoRead, bwrapInfoWrite, err := os.Pipe()
	if err != nil {
		panic(err)
	}
	defer bwrapInfoRead.Close()
	defer bwrapInfoWrite.Close()
	bwrapBlockRead, bwrapBlockWrite, err := os.Pipe()
	if err != nil {
		panic(err)
	}
	defer bwrapBlockRead.Close()
	defer bwrapBlockWrite.Close()
	bwrap.ExtraFiles = []*os.File{bwrapInfoWrite, bwrapBlockRead}

	if err := bwrap.Start(); err != nil {
		panic(err)
	}
	defer bwrap.Wait()
	defer syscall.Kill(-bwrap.Process.Pid, syscall.SIGKILL)

	if err := bwrapInfoWrite.Close(); err != nil {
		panic(err)
	}
	if err := bwrapBlockRead.Close(); err != nil {
		panic(err)
	}

	var bwrapInfo BwrapInfo
	if bytes, err := ioutil.ReadAll(bwrapInfoRead); err == nil {
		if err := json.Unmarshal(bytes, &bwrapInfo); err != nil {
			panic(err)
		}
		if bwrapInfo.ChildPid <= 0 {
			panic("Unexpected child PID")
		}
	} else {
		panic(err)
	}
	if err := bwrapInfoRead.Close(); err != nil {
		panic(err)
	}

	if usePasta {
		pastaExe := envOr("PASTA_EXE", "pasta")
		pastaArgs := readJsonArgs(pastaArgsJson)
		pastaArgs = append(pastaArgs, "--")
		pastaArgs = append(pastaArgs, strconv.Itoa(bwrapInfo.ChildPid))

		pasta := exec.Command(pastaExe, pastaArgs...)
		pasta.Stdout = os.Stdout
		pasta.Stderr = os.Stderr

		if err := pasta.Run(); err != nil {
			panic(err)
		}
	}

	if _, err := bwrapBlockWrite.Write([]byte{'x'}); err != nil {
		panic(err)
	}
	if err := bwrapBlockWrite.Close(); err != nil {
		panic(err)
	}

	if err := bwrap.Wait(); err != nil {
		if exiterr, ok := err.(*exec.ExitError); ok {
			return exiterr
		} else {
			panic(err)
		}
	}

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
