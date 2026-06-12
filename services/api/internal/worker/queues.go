package worker

import "strings"

type Role string

const (
	RoleAll     Role = "all"
	RoleMail    Role = "mail"
	RoleReports Role = "reports"
)

func ParseRole(s string) Role {
	switch strings.ToLower(strings.TrimSpace(s)) {
	case "mail", "email":
		return RoleMail
	case "reports", "report":
		return RoleReports
	default:
		return RoleAll
	}
}

func (r Role) String() string { return string(r) }
