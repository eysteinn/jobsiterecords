package email

import (
	"context"
	"crypto/tls"
	"fmt"
	"net"
	"net/smtp"
	"strings"

	"github.com/eysteinn/jobsiterecords/services/api/internal/config"
)

type SMTPConfig struct {
	Host      string
	Port      int
	Username  string
	Password  string
	FromEmail string
	FromName  string
}

func SMTPFromConfig(cfg config.Config) SMTPConfig {
	return SMTPConfig{
		Host:      cfg.SMTPHost,
		Port:      cfg.SMTPPort,
		Username:  cfg.SMTPUsername,
		Password:  cfg.SMTPPassword,
		FromEmail: cfg.SMTPFromEmail,
		FromName:  cfg.SMTPFromName,
	}
}

func (c SMTPConfig) Enabled() bool {
	return c.Host != "" && c.Username != "" && c.Password != "" && c.FromEmail != ""
}

func (c SMTPConfig) Send(ctx context.Context, to, subject, body string) error {
	if !c.Enabled() {
		return fmt.Errorf("smtp not configured")
	}

	addr := fmt.Sprintf("%s:%d", c.Host, c.Port)
	fromHeader := formatAddress(c.FromName, c.FromEmail)
	msg := strings.Join([]string{
		"From: " + fromHeader,
		"To: " + to,
		"Subject: " + subject,
		"MIME-Version: 1.0",
		"Content-Type: text/plain; charset=UTF-8",
		"",
		body,
	}, "\r\n")

	var dialer net.Dialer
	conn, err := dialer.DialContext(ctx, "tcp", addr)
	if err != nil {
		return fmt.Errorf("smtp connect: %w", err)
	}

	client, err := smtp.NewClient(conn, c.Host)
	if err != nil {
		conn.Close()
		return fmt.Errorf("smtp client: %w", err)
	}
	defer client.Close()

	if ok, _ := client.Extension("STARTTLS"); ok {
		if err := client.StartTLS(&tls.Config{ServerName: c.Host}); err != nil {
			return fmt.Errorf("smtp starttls: %w", err)
		}
	}

	auth := smtp.PlainAuth("", c.Username, c.Password, c.Host)
	if err := client.Auth(auth); err != nil {
		return fmt.Errorf("smtp auth: %w", err)
	}
	if err := client.Mail(c.FromEmail); err != nil {
		return fmt.Errorf("smtp mail from: %w", err)
	}
	if err := client.Rcpt(to); err != nil {
		return fmt.Errorf("smtp rcpt: %w", err)
	}

	w, err := client.Data()
	if err != nil {
		return fmt.Errorf("smtp data: %w", err)
	}
	if _, err := w.Write([]byte(msg)); err != nil {
		return fmt.Errorf("smtp write: %w", err)
	}
	if err := w.Close(); err != nil {
		return fmt.Errorf("smtp data close: %w", err)
	}
	return client.Quit()
}

func formatAddress(name, addr string) string {
	if name == "" {
		return addr
	}
	return fmt.Sprintf("%s <%s>", name, addr)
}
