package email

import (
	"context"
	"fmt"
	"log"

	"github.com/jackc/pgx/v5"
	"github.com/riverqueue/river"
)

// Queue enqueues outbound email for the worker process. In dev mode it logs links instead.
type Queue struct {
	river  *river.Client[pgx.Tx]
	devLog bool
}

func NewQueue(riverClient *river.Client[pgx.Tx], devLog bool) *Queue {
	return &Queue{river: riverClient, devLog: devLog}
}

func (q *Queue) SendMagicLink(ctx context.Context, to, link string) error {
	subject := "Sign in to Job Site Records"
	body := fmt.Sprintf("Click to sign in:\n\n%s\n\nThis link expires in 15 minutes.", link)
	return q.enqueue(ctx, to, subject, body, link)
}

func (q *Queue) SendPasswordReset(ctx context.Context, to, link string) error {
	subject := "Reset your Job Site Records password"
	body := fmt.Sprintf("Click to reset your password:\n\n%s\n\nThis link expires in 30 minutes.", link)
	return q.enqueue(ctx, to, subject, body, link)
}

func (q *Queue) SendWorkspaceInvite(ctx context.Context, to, workspaceName, link string) error {
	subject := fmt.Sprintf("You're invited to %s on Job Site Records", workspaceName)
	body := fmt.Sprintf(
		"You've been invited to join %s on Job Site Records.\n\nAccept the invite:\n\n%s\n\nThis link expires in 7 days.",
		workspaceName,
		link,
	)
	return q.enqueue(ctx, to, subject, body, link)
}

func (q *Queue) enqueue(ctx context.Context, to, subject, body, devLink string) error {
	if q.devLog {
		log.Printf("[email] to=%s subject=%q link=%s", to, subject, devLink)
		return nil
	}
	_, err := q.river.Insert(ctx, SendEmailArgs{
		To:      to,
		Subject: subject,
		Body:    body,
	}, nil)
	return err
}
