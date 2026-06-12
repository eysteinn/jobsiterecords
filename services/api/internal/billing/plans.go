package billing

import "strings"

// Plan describes an internal subscription SKU.
type Plan struct {
	SKU         string `json:"sku"`
	DisplayName string `json:"display_name"`
	MemberLimit int    `json:"member_limit"`
	PriceID     string `json:"price_id"`
	PriceCents  int    `json:"price_cents"`
}

// Catalog returns launch monthly plans keyed by SKU.
func Catalog(priceIDs map[string]string) []Plan {
	return []Plan{
		{
			SKU:         "solo_1",
			DisplayName: "Solo",
			MemberLimit: 1,
			PriceID:     priceIDs["solo_1"],
			PriceCents:  1900,
		},
		{
			SKU:         "crew_5",
			DisplayName: "Crew",
			MemberLimit: 5,
			PriceID:     priceIDs["crew_5"],
			PriceCents:  4900,
		},
		{
			SKU:         "team_15",
			DisplayName: "Team",
			MemberLimit: 15,
			PriceID:     priceIDs["team_15"],
			PriceCents:  9900,
		},
	}
}

func PlanBySKU(catalog []Plan, sku string) (Plan, bool) {
	for _, p := range catalog {
		if p.SKU == sku {
			return p, true
		}
	}
	return Plan{}, false
}

func PlanByPriceID(catalog []Plan, priceID string) (Plan, bool) {
	priceID = strings.TrimSpace(priceID)
	if priceID == "" {
		return Plan{}, false
	}
	for _, p := range catalog {
		if p.PriceID == priceID {
			return p, true
		}
	}
	return Plan{}, false
}

func DisplayNameForSKU(sku string) string {
	switch sku {
	case "solo_1":
		return "Solo"
	case "crew_5":
		return "Crew"
	case "team_15":
		return "Team"
	default:
		return sku
	}
}

