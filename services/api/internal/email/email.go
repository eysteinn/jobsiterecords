package email

import (
	"fmt"
	"log"
)

type Sender struct {
	devLog bool
}

func New(devLog bool) *Sender {
	return &Sender{devLog: devLog}
}

func (s *Sender) SendMagicLink(to, link string) error {
	subject := "Sign in to Job Site Records"
	body := fmt.Sprintf("Click to sign in:\n\n%s\n\nThis link expires in 15 minutes.", link)
	return s.send(to, subject, body, link)
}

func (s *Sender) SendPasswordReset(to, link string) error {
	subject := "Reset your Job Site Records password"
	body := fmt.Sprintf("Click to reset your password:\n\n%s\n\nThis link expires in 30 minutes.", link)
	return s.send(to, subject, body, link)
}

func (s *Sender) SendWorkspaceInvite(to, workspaceName, link string) error {
	subject := fmt.Sprintf("You're invited to %s on Job Site Records", workspaceName)
	body := fmt.Sprintf(
		"You've been invited to join %s on Job Site Records.\n\nAccept the invite:\n\n%s\n\nThis link expires in 7 days.",
		workspaceName,
		link,
	)
	return s.send(to, subject, body, link)
}

func (s *Sender) send(to, subject, body, link string) error {
	if s.devLog {
		log.Printf("[email] to=%s subject=%q link=%s", to, subject, link)
		return nil
	}
	// Production: wire Resend/Postmark here.
	log.Printf("[email] would send to=%s subject=%q (no provider configured)", to, subject)
	return nil
}
