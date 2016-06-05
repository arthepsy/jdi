package main

import (
	"bytes"
	"errors"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
)

type Server struct {
	bind net.Listener
	key  string
	data chan []byte
	cmd  chan string
}

func parseNetstring(data []byte) ([]byte, error) {
	n := len(data)
	if data[n-1] != byte(',') {
		return nil, errors.New("no terminator")
	}
	p := bytes.Index(data, []byte{':'})
	if p == -1 {
		return nil, errors.New("no separator")
	}
	ml, err := strconv.ParseUint(string(data[:p]), 10, 64)
	if err != nil || uint64(n) != uint64(p)+ml+2 {
		return nil, errors.New("invalid length")
	}
	return data[p+1 : n-1], nil
}

func openURI(s string) {
	var cmd string
	var args []string = nil
	switch runtime.GOOS {
	case "windows":
		cmd = "cmd"
		args = []string{"/c", "start"}
		s = strings.Replace(s, "&", "^&", -1)
	case "darwin":
		cmd = "open"
	case "freebsd":
		fallthrough
	case "openbsd":
		fallthrough
	case "netbsd":
		fallthrough
	case "linux":
		cmd = "xdg-open"
	default:
		log.Printf("error: unknown runtime %s\n", runtime.GOOS)
		return
	}
	if args != nil {
		exec.Command(cmd, append(args, s)...).Run()
	} else {
		exec.Command(cmd).Run()
	}
}

func (s Server) Close() {
	s.bind.Close()
}

func (s Server) RunCommand(action, rest string) {
	switch action {
	case "stop":
		s.Close()
	case "browse":
		openURI(rest)
	case "exec":
		args := strings.Fields(rest)
		cmd := args[0]
		args = args[1:]
		exec.Command(cmd, args...).Run()
	default:
		log.Printf("unknown command: %s\n", action)
	}
}

func (s Server) HandleCommand() {
	for cmd := range s.cmd {
		log.Printf("command: %s\n", cmd)
		r := strings.SplitN(cmd, " ", 2)
		var rest string
		if len(r) > 1 {
			rest = r[1]
		} else {
			rest = ""
		}
		go s.RunCommand(r[0], rest)
	}
}

func (s Server) HandleDecode() {
	for rdata := range s.data {
		// netstrings
		pdata, err := parseNetstring(rdata)
		if err != nil {
			log.Printf("error: %v", err)
			continue
		}
		// key/command
		p := bytes.Index(pdata, []byte{' '})
		if p == -1 {
			log.Printf("error: invalid protocol\n")
			continue
		}
		clikey := string(pdata[:p])
		if s.key != clikey {
			log.Printf("error: invalid key '%s'\n", clikey)
			continue
		}
		s.cmd <- string(pdata[p+1:])
	}
}

func (s Server) HandleClient(c net.Conn) {
	log.Printf("client connected (%v)\n", c.RemoteAddr())
	buf := make([]byte, 4096)
	for {
		n, err := c.Read(buf)
		if err != nil || n == 0 {
			c.Close()
			break
		}
		s.data <- buf[0:n]
	}
}

func (s Server) Serve() {
	go s.HandleDecode()
	go s.HandleCommand()
	defer s.Close()
	for {
		c, err := s.bind.Accept()
		if err != nil {
			log.Fatal(err)
		}
		go s.HandleClient(c)
	}
}

func NewServer(l net.Listener, key string) *Server {
	return &Server{l, key, make(chan []byte), make(chan string)}
}

func runServer(port int, key string) {
	l, err := net.Listen("tcp", ":"+strconv.Itoa(port))
	if err != nil {
		log.Fatal(err)
	}
	srv := NewServer(l, key)
	log.Printf("listening on port " + strconv.Itoa(port))
	srv.Serve()
}

func main() {
	flag.Usage = func() {
		prog := filepath.Base(os.Args[0])
		fmt.Fprintf(os.Stderr, "usage: %s -p PORT -k KEYFILE\n", prog)
		os.Exit(2)
	}

	port := flag.Int("p", 0, "port to listen")
	keyfile := flag.String("k", "", "path to key file")
	flag.Parse()
	if 0 > *port || *port > 65535 {
		flag.Usage()
	}
	_, err := os.Stat(*keyfile)
	if os.IsNotExist(err) {
		flag.Usage()
	}

	rkey, err := ioutil.ReadFile(*keyfile)
	key := strings.TrimSpace(string(rkey))
	if len(key) == 0 {
		fmt.Fprintf(os.Stderr, "error: empty key\n")
		os.Exit(1)
	}

	runServer(*port, key)
}
