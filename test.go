package main

import (
	"bufio"
	"fmt"
	"github.com/rlmcpherson/s3gof3r"
	"io"
	"net/http"
	"os"
	"os/exec"
	"time"
)

const (
	ProgressSize =  8 * 1024 * 1024
)

func main() {
	fmt.Println("running transfer")
	backupKey := fmt.Sprintf("test/fake-%v.backup", time.Now().Unix())
	err := transfer(os.Getenv("FROM_URL"), os.Getenv("S3_BUCKET"), backupKey)
	if err == nil {
		fmt.Println("transfer completed")
	} else {
		fmt.Printf("transfer failed: %v\n", err)
	}
}

func transfer(from, bucket, key string) error {
	dump, err := NewPGDump(from)
	if err != nil {
		return err
	}
	data, err := dump.Data()
	if err != nil {
		return err
	}
	log, err := dump.Log()
	if err != nil {
		return err
	}
	go func() {
		scanner := bufio.NewScanner(log)
		for scanner.Scan() {
			fmt.Println(scanner.Text())
		}

		if err := scanner.Err(); err != nil {
			fmt.Print("pg_dump failed reading output: ", err)
		}
	}()
	err = Upload(bucket, key, data)
	if err != nil {
		fmt.Print("upload failed: ", err)
	}
	return dump.Wait()
}

type PGDump struct {
	cmd *exec.Cmd
}

func (pgd *PGDump) Data() (io.ReadCloser, error) {
	return pgd.cmd.StdoutPipe()
}

func (pgd *PGDump) Log() (io.ReadCloser, error) {
	return pgd.cmd.StderrPipe()
}

func NewPGDump(source string) (*PGDump, error) {
	cmd := exec.Command("pg_dump", "--verbose", "--no-owner",
		"--no-privilges", "--format", "custom", source)
	err := cmd.Start()
	if err != nil {
		return nil, err
	}
	return &PGDump{cmd}, nil
}

func (pgd *PGDump) Wait() error {
	return pgd.cmd.Wait()
}
	
func Upload(bucket, key string, source io.Reader) (err error) {
	keys, err := s3gof3r.EnvKeys()
	if err != nil {
		return
	}
	
	s3 := s3gof3r.New(s3gof3r.DefaultDomain, keys)
	b := s3.Bucket(bucket)
	dest, err := b.PutWriter(key, make(http.Header), s3gof3r.DefaultConfig)
	if err != nil {
		return
	}

	for tot, chunk, err := int64(0), int64(0), error(nil); err == nil; chunk, err = io.CopyN(dest, source, ProgressSize) {
		tot += chunk
		totMB := int(float64(tot) / (1024 * 1024))
		fmt.Printf("uploaded %vMB\n", totMB)
	}
	if err != nil && err != io.EOF {
		return
	}
	err = dest.Close()
	return
}
