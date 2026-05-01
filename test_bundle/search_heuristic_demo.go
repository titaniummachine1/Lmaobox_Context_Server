package main

import (
	"fmt"
)

type SearchResult struct {
	Symbol      string
	Score       float64
	Description string
}

// Heuristic: show all results above threshold, up to limit
func FilterSearchResults(results []SearchResult, threshold float64, limit int) []SearchResult {
	filtered := make([]SearchResult, 0, limit)
	for _, r := range results {
		if r.Score >= threshold {
			filtered = append(filtered, r)
			if len(filtered) >= limit {
				break
			}
		}
	}
	return filtered
}

func main() {
	results := []SearchResult{
		{"engine.TraceLine", 0.98, "Traces a line in the engine."},
		{"draw.Color", 0.95, "Sets the drawing color."},
		{"entities.GetPlayerResources", 0.80, "Gets player resources."},
		{"entities.GetLocalPlayer", 0.78, "Gets the local player entity."},
		{"TF_CUSTOM_MERASMUS_PLAYER_BOMB", 0.60, "A constant."},
		{"CONTENTS_PLAYERCLIP", 0.55, "A constant."},
	}

	threshold := 0.75
	limit := 3
	filtered := FilterSearchResults(results, threshold, limit)

	fmt.Println("Filtered Results:")
	for _, r := range filtered {
		fmt.Printf("%s (%.2f): %s\n", r.Symbol, r.Score, r.Description)
	}
}
