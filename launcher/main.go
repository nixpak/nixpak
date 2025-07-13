package main

import (
	"crypto/md5"
	"encoding/base32"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"syscall"

	"github.com/fsnotify/fsnotify"
	"golang.org/x/sys/unix"
)

type JsonRaw = map[string]any
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
	i.Id = instanceId()
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

func requiredEnv(name string) string {
	val, found := os.LookupEnv(name)
	if !found || val == "" {
		panic(fmt.Sprintf("environment variable '%s' not set", name))
	}
	return val
}

func valToString(item any) (ret string) {
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
	bytes, _ := io.ReadAll(file)
	var argsRaw []any

	json.Unmarshal(bytes, &argsRaw)
	for _, item := range argsRaw {
		args = append(args, valToString(item))
	}
	return
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

type Config struct {
	AppExe                  string
	AppArgs                 []string
	BwrapExe                string
	BwrapArgs               []string
	UseDbusProxy            bool
	DbusproxyExe            string
	DbusproxyArgs           []string
	UsePasta                bool
	PastaExe                string
	PastaArgs               []string
	UseFlatpakMetadata      bool
	FlatpakMetadataTemplate string
	UseWaylandProxy         bool
	WaylandProxyExe         string
	WaylandProxyArgs        []string
	WaylandProxySocketPath  string
}

func readConfig() (conf Config) {
	appExe, foundAppExe := os.LookupEnv("NIXPAK_APP_EXE")
	if !foundAppExe {
		panic("No executable given")
	}
	conf.AppExe = appExe
	conf.AppArgs = os.Args[1:]

	bwrapArgsJson, foundBwrapArgs := os.LookupEnv("BUBBLEWRAP_ARGS")
	if !foundBwrapArgs {
		panic("No bubblewrap args given")
	}
	conf.BwrapArgs = readJsonArgs(bwrapArgsJson)
	conf.BwrapExe = envOr("BWRAP_EXE", "bwrap")

	dbusproxyArgsJson, useDbusProxy := os.LookupEnv("XDG_DBUS_PROXY_ARGS")
	conf.UseDbusProxy = useDbusProxy
	if useDbusProxy {
		conf.DbusproxyArgs = readJsonArgs(dbusproxyArgsJson)
		conf.DbusproxyExe = envOr("XDG_DBUS_PROXY_EXE", "xdg-dbus-proxy")
	}

	pastaArgsJson, usePasta := os.LookupEnv("PASTA_ARGS")
	conf.UsePasta = usePasta
	if usePasta {
		conf.PastaArgs = readJsonArgs(pastaArgsJson)
		conf.PastaExe = envOr("PASTA_EXE", "pasta")
	}

	flatpakMetadataTemplate, useFlatpakMetadata := os.LookupEnv("FLATPAK_METADATA_TEMPLATE")
	conf.UseFlatpakMetadata = useFlatpakMetadata
	if useFlatpakMetadata {
		conf.FlatpakMetadataTemplate = flatpakMetadataTemplate
	}

	waylandProxyArgsJson, useWaylandProxy := os.LookupEnv("WAYLAND_PROXY_ARGS")
	conf.UseWaylandProxy = useWaylandProxy
	if useWaylandProxy {
		conf.WaylandProxyArgs = readJsonArgs(waylandProxyArgsJson)
		conf.WaylandProxyExe = envOr("WAYLAND_PROXY_EXE", "wayland-proxy-virtwl")
		conf.WaylandProxySocketPath = requiredEnv("XDG_RUNTIME_DIR") + "/nixpak-wayland-" + instanceId()

		if _, err := os.Stat(conf.WaylandProxySocketPath); err == nil {
			panic("Wayland proxy socket already exists")
		}
	}

	return
}

type Dbus struct {
	Cmd      *exec.Cmd
	SyncRead *os.File
}

func StartDbusproxy(conf Config) (dbus Dbus) {
	failed := true

	dbusproxyArgs := append([]string{"--fd=3"}, conf.DbusproxyArgs...)

	cmd := exec.Command(conf.DbusproxyExe, dbusproxyArgs...)
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
		waylandProxySocketPathInner := requiredEnv("XDG_RUNTIME_DIR") + "/nixpak-wayland"
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
