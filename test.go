package main

import (
	"bufio"
	"fmt"
	"github.com/rlmcpherson/s3gof3r"
	"database/sql"
	_ "github.com/lib/pq"
	"io"
	"net/http"
	"os"
	"os/exec"
	"syscall"
	"time"
)

const (
	ProgressSize =  8 * 1024 * 1024
)

func schemaSetup(db *sql.DB) error {
	ddl := []string{`CREATE EXTENSION IF NOT EXISTS "uuid-ossp"`,
		`CREATE TABLE IF NOT EXISTS transfers(
    uuid uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    created_at timestamptz NOT NULL DEFAULT now(),
    from_url text NOT NULL,
    s3_key text NOT NULL,
    db_size_bytes bigint NOT NULL,
    exit_status int,
    finished_at timestamptz)`,
		`CREATE TABLE IF NOT EXISTS logs(
    uuid uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    transfer_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    message text NOT NULL,
    FOREIGN KEY (transfer_id) REFERENCES transfers(uuid))`,
	}

	for _, stmt := range ddl {
		_, err := db.Exec(stmt)
		if err != nil {
			return err
		}
	}
	return nil
}



func main() {
	db, err := sql.Open("postgres", os.Getenv("DATABASE_URL"))
	if err != nil {
		panic(fmt.Sprintf("Could not connect to DB: %v", err))
	}
	defer db.Close()
	err = schemaSetup(db)
	if err != nil {
		panic(fmt.Sprintf("Could not set up schema: %v", err))
	}

	fmt.Println("running transfer")
	backupKey := fmt.Sprintf("test/fake-%v.backup", time.Now().Unix())
	err = transfer(db, os.Getenv("FROM_URL"), os.Getenv("S3_BUCKET"), backupKey)
	if err == nil {
		fmt.Println("transfer completed")
	} else {
		fmt.Printf("transfer failed: %v\n", err)
	}
}

func transfer(db *sql.DB, from, bucket, key string) error {
	fromDB, err := sql.Open("postgres", from)
	if err != nil {
		return fmt.Errorf("Failed to connect to target: %v", err)
	}
	defer fromDB.Close()
	var fromDBSize uint64
	err = fromDB.QueryRow("SELECT pg_database_size(current_database())").Scan(&fromDBSize)
	if err != nil {
		return fmt.Errorf("Failed to get target size: %v", err)
	}
	var transferId string
	err = db.QueryRow("INSERT INTO transfers(from_url, db_size_bytes, s3_key) VALUES($1, $2, $3) RETURNING uuid",
		from, fromDBSize, key).Scan(&transferId)
	if err != nil {
		return fmt.Errorf("Failed to record transfer: %v", err)
	}

	dump := NewPGDump(from)
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
			_, err := db.Exec("INSERT INTO logs(transfer_id, message) VALUES($1, $2)",
				transferId, scanner.Text())
			if err != nil {
				fmt.Print("failed to log: ", err)
			}
		}

		if err := scanner.Err(); err != nil {
			fmt.Print("pg_dump failed reading output: ", err)
		}
	}()
	dump.Start()
	err = Upload(bucket, key, data)
	if err != nil {
		// TODO: kill source on failure
		fmt.Print("upload failed: ", err)
	}
	err = dump.Wait()
	exitStatus := 255
        if err == nil {
		exitStatus = 0
	} else {
		if exiterr, ok := err.(*exec.ExitError); ok {
			if status, ok := exiterr.Sys().(syscall.WaitStatus); ok {
				exitStatus = status.ExitStatus()
			}
		} else {
			fmt.Print("Could not determine exit status", err)
		}
	}

	_, dbErr := db.Exec("UPDATE transfers SET finished_at = now(), exit_status = $1 WHERE uuid = $2",
		exitStatus, transferId)
	if err == nil {
		return dbErr
	} else {
		return err
	}
}

type PGDump struct {
	cmd *exec.Cmd
}

func (pgd *PGDump) Start() error {
	return pgd.cmd.Start()
}

func (pgd *PGDump) Data() (io.ReadCloser, error) {
	return pgd.cmd.StdoutPipe()
}

func (pgd *PGDump) Log() (io.ReadCloser, error) {
	return pgd.cmd.StderrPipe()
}

func NewPGDump(source string) *PGDump {
	cmd := exec.Command("pg_dump", "--verbose", "--no-owner",
		"--no-privileges", "--format", "custom", source)
	return &PGDump{cmd}
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
