package email

// SendEmailArgs is the River job payload for outbound transactional email.
type SendEmailArgs struct {
	To      string `json:"to"`
	Subject string `json:"subject"`
	Body    string `json:"body"`
}

func (SendEmailArgs) Kind() string { return "send_email" }
