package main

import (
	"crypto/md5"
	"encoding/base32"
	"encoding/json"
	"io/ioutil"
	"os"
	"os/exec"
	"strconv"
	"time"
)

type JsonRaw = map[string]interface{}

type EnvVar struct {
	Type string
	Key  string
}

func NewEnvVar(raw JsonRaw) (e EnvVar) {
	e.Type = "env"
	e.Key = raw["key"].(string)
	return
}

func (e EnvVar) String() string {
	return os.Getenv(e.Key)
}

type Concat struct {
	Type string
	A    string
	B    string
}

func NewConcat(raw JsonRaw) (c Concat) {
	c.Type = "env"
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

func main() {
	bwrapExe := envOr("BWRAP_EXE", "bwrap")

	bwrapArgsJson, foundBwrapArgs := os.LookupEnv("BUBBLEWRAP_ARGS")
	if !foundBwrapArgs {
		panic("No bubblewrap args given")
	}
	dbusproxyArgsJson, useDbusProxy := os.LookupEnv("XDG_DBUS_PROXY_ARGS")

	var r, w *os.File
	var dbusproxyExe string
	if useDbusProxy {
		dbusproxyExe = envOr("XDG_DBUS_PROXY_EXE", "xdg-dbus-proxy")
		var err error
		r, w, err = os.Pipe()
		if err != nil {
			panic(err)
		}
	}

	bwrapArgs := readJsonArgs(bwrapArgsJson)
	if useDbusProxy {
		bwrapArgs = append([]string{"--sync-fd", "3"}, bwrapArgs...)
	}
	bwrapArgs = append(bwrapArgs, os.Args[1:]...)
	cmd := exec.Command(bwrapExe, bwrapArgs...)

	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if useDbusProxy {
		dbusproxyArgs := readJsonArgs(dbusproxyArgsJson)
		dbus := exec.Command(dbusproxyExe, append([]string{"--fd=3"}, dbusproxyArgs...)...)
		dbus.Stdout = os.Stdout
		dbus.Stderr = os.Stderr

		defer w.Close()
		defer r.Close()

		dbus.ExtraFiles = []*os.File{w}
		cmd.ExtraFiles = []*os.File{r}

		if err := dbus.Start(); err != nil {
			panic(err)
		}
	}
	time.Sleep(100 * time.Millisecond)

	cmd.Run()
}
