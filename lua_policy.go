package main

import (
	"fmt"
	"os"
	"regexp"
	"strings"
)

type LboxMutationPolicy struct {
	RequireDepthZeroRegister    bool
	RequireDepthZeroUnregister  bool
	RequireKillSwitchOrder      bool
	ForbidRuntimeUnregister     bool
	ForbidCollectGarbage        bool
	ForbidRequireInFunction     bool
	ForbidGlobalTable           bool
	ForbidCreateFontInFunction  bool
	ForbidLegacyBitLibrary      bool
	ForbidDeprecatedCallbacks   bool
	ForbidAllowListener         bool
	ForbidForceFullUpdate       bool
	RequireDrawTextFontSetup    bool
	ForbidWarpOutsideCreateMove bool
	ForbidSuspiciousSetupBones  bool
	ForbidIpairsOnFindByClass   bool
}

type luaPolicyViolation struct {
	Line    int
	Message string
}

type luaPolicyBlockKind int

const (
	luaBlockGeneric luaPolicyBlockKind = iota
	luaBlockFunction
	luaBlockRepeat
)

var defaultLboxMutationPolicy = LboxMutationPolicy{
	RequireDepthZeroRegister:    true,
	RequireDepthZeroUnregister:  true,
	RequireKillSwitchOrder:      true,
	ForbidRuntimeUnregister:     true,
	ForbidCollectGarbage:        true,
	ForbidRequireInFunction:     true,
	ForbidGlobalTable:           true,
	ForbidCreateFontInFunction:  true,
	ForbidLegacyBitLibrary:      true,
	ForbidDeprecatedCallbacks:   true,
	ForbidAllowListener:         true,
	ForbidForceFullUpdate:       true,
	RequireDrawTextFontSetup:    true,
	ForbidWarpOutsideCreateMove: true,
	ForbidSuspiciousSetupBones:  true,
	ForbidIpairsOnFindByClass:   true,
}

func checkLuaCallbackMutationPolicy(filePath string, policy LboxMutationPolicy) ([]luaPolicyViolation, error) {
	contentBytes, err := os.ReadFile(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to read file for policy scan: %v", err)
	}
	content := string(contentBytes)

	tokens, err := tokenizeLua(content)
	if err != nil {
		return nil, err
	}

	violations := make([]luaPolicyViolation, 0)
	blockStack := make([]luaPolicyBlockKind, 0)
	functionDepth := 0
	unregisteredAtDepthZero := make(map[string]bool)
	hasDrawSetFont := hasQualifiedCall(tokens, "draw", "SetFont")
	hasDrawText := hasQualifiedCall(tokens, "draw", "Text")

	for i := 0; i < len(tokens); i++ {
		tok := tokens[i]

		if method, args, endIndex, ok := extractCallbacksCall(tokens, i); ok {
			line := tok.Line
			eventName := stringArgValue(args, 0)
			uniqueID := stringArgValue(args, 1)

			if strings.EqualFold(method, "register") {
				if policy.ForbidDeprecatedCallbacks && strings.EqualFold(eventName, "PostPropUpdate") {
					violations = append(violations, luaPolicyViolation{Line: line, Message: "CRITICAL: PostPropUpdate is deprecated legacy-only callback usage — use FrameStageNotify instead"})
				}
				if policy.RequireDepthZeroRegister && functionDepth > 0 {
					violations = append(violations, luaPolicyViolation{Line: line, Message: "CRITICAL: callbacks.Register must be declared at depth 0 (global scope only)"})
				}
				if policy.RequireKillSwitchOrder && functionDepth == 0 && eventName != "" {
					killSwitchKeyExact := strings.ToLower(eventName + "|" + uniqueID)
					killSwitchKeyEvent := strings.ToLower(eventName + "|")
					hasExactMatch := unregisteredAtDepthZero[killSwitchKeyExact]
					hasEventMatch := unregisteredAtDepthZero[killSwitchKeyEvent]
					if uniqueID != "" && !hasExactMatch && !hasEventMatch {
						violations = append(violations, luaPolicyViolation{Line: line, Message: fmt.Sprintf("CRITICAL: Kill-Switch violation for id '%s' on event '%s': callbacks.Unregister must appear before callbacks.Register at depth 0", uniqueID, eventName)})
					}
				}
			}

			if strings.EqualFold(method, "unregister") {
				if policy.ForbidDeprecatedCallbacks && strings.EqualFold(eventName, "PostPropUpdate") {
					violations = append(violations, luaPolicyViolation{Line: line, Message: "CRITICAL: PostPropUpdate is deprecated legacy-only callback usage — use FrameStageNotify instead"})
				}
				reportedRuntimeUnregister := false
				if policy.ForbidRuntimeUnregister && functionDepth > 0 {
					violations = append(violations, luaPolicyViolation{Line: line, Message: "CRITICAL: Illegal Unregister inside function scope (including Unload). Runtime callback table mutation is forbidden"})
					reportedRuntimeUnregister = true
				}
				if policy.RequireDepthZeroUnregister && functionDepth > 0 && !reportedRuntimeUnregister {
					violations = append(violations, luaPolicyViolation{Line: line, Message: "CRITICAL: callbacks.Unregister must be declared at depth 0 (global scope only)"})
				}
				if functionDepth == 0 && eventName != "" {
					if uniqueID != "" {
						unregisteredAtDepthZero[strings.ToLower(eventName+"|"+uniqueID)] = true
					} else {
						unregisteredAtDepthZero[strings.ToLower(eventName+"|")] = true
					}
				}
			}

			if policy.ForbidWarpOutsideCreateMove && strings.EqualFold(method, "register") {
				if callbackLine := findQualifiedCallLineInArgs(args, "warp", []string{"TriggerWarp", "TriggerDoubleTap", "TriggerCharge"}); callbackLine > 0 && !strings.EqualFold(eventName, "CreateMove") {
					violations = append(violations, luaPolicyViolation{Line: callbackLine, Message: "CRITICAL: warp trigger calls must be made from a CreateMove callback only"})
				}
			}

			for j := i; j < endIndex; j++ {
				t := tokens[j]
				if t.Kind == "keyword" {
					switch t.Text {
					case "function":
						blockStack = append(blockStack, luaBlockFunction)
						functionDepth++
					case "end":
						if len(blockStack) > 0 {
							for k := len(blockStack) - 1; k >= 0; k-- {
								if blockStack[k] == luaBlockRepeat {
									continue
								}
								if blockStack[k] == luaBlockFunction && functionDepth > 0 {
									functionDepth--
								}
								blockStack = append(blockStack[:k], blockStack[k+1:]...)
								break
							}
						}
					}
				}
				if t.Kind == "ident" && strings.EqualFold(t.Text, "callbacks") {
					if nestedMethod, _, _, nestedOk := extractCallbacksCall(tokens, j); nestedOk {
						nestedLine := t.Line
						if strings.EqualFold(nestedMethod, "unregister") && policy.ForbidRuntimeUnregister && functionDepth > 0 {
							violations = append(violations, luaPolicyViolation{Line: nestedLine, Message: "CRITICAL: Illegal Unregister inside function scope (including Unload). Runtime callback table mutation is forbidden"})
						}
						if strings.EqualFold(nestedMethod, "register") && policy.RequireDepthZeroRegister && functionDepth > 0 {
							violations = append(violations, luaPolicyViolation{Line: nestedLine, Message: "CRITICAL: callbacks.Register must be declared at depth 0 (global scope only)"})
						}
					}
				}
			}

			i = endIndex
			continue
		}

		if tok.Kind == "keyword" {
			switch tok.Text {
			case "function":
				blockStack = append(blockStack, luaBlockFunction)
				functionDepth++
			case "if", "for", "while", "do":
				blockStack = append(blockStack, luaBlockGeneric)
			case "repeat":
				blockStack = append(blockStack, luaBlockRepeat)
			case "end":
				if len(blockStack) > 0 {
					for j := len(blockStack) - 1; j >= 0; j-- {
						if blockStack[j] == luaBlockRepeat {
							continue
						}
						if blockStack[j] == luaBlockFunction && functionDepth > 0 {
							functionDepth--
						}
						blockStack = append(blockStack[:j], blockStack[j+1:]...)
						break
					}
				}
			case "until":
				if len(blockStack) > 0 {
					for j := len(blockStack) - 1; j >= 0; j-- {
						if blockStack[j] == luaBlockRepeat {
							blockStack = append(blockStack[:j], blockStack[j+1:]...)
							break
						}
					}
				}
			}
		}
	}

	functionDepth2 := 0
	blockStack2 := make([]luaPolicyBlockKind, 0)
	for i := 0; i < len(tokens); i++ {
		tok := tokens[i]
		if tok.Kind == "keyword" {
			switch tok.Text {
			case "function":
				blockStack2 = append(blockStack2, luaBlockFunction)
				functionDepth2++
			case "if", "for", "while", "do":
				blockStack2 = append(blockStack2, luaBlockGeneric)
			case "repeat":
				blockStack2 = append(blockStack2, luaBlockRepeat)
			case "end":
				if len(blockStack2) > 0 {
					for j := len(blockStack2) - 1; j >= 0; j-- {
						if blockStack2[j] == luaBlockRepeat {
							continue
						}
						if blockStack2[j] == luaBlockFunction && functionDepth2 > 0 {
							functionDepth2--
						}
						blockStack2 = append(blockStack2[:j], blockStack2[j+1:]...)
						break
					}
				}
			case "until":
				if len(blockStack2) > 0 {
					for j := len(blockStack2) - 1; j >= 0; j-- {
						if blockStack2[j] == luaBlockRepeat {
							blockStack2 = append(blockStack2[:j], blockStack2[j+1:]...)
							break
						}
					}
				}
			}
			continue
		}
		if tok.Kind != "ident" {
			continue
		}
		if policy.ForbidCollectGarbage && tok.Text == "collectgarbage" && i+1 < len(tokens) && tokens[i+1].Kind == "symbol" && tokens[i+1].Text == "(" {
			violations = append(violations, luaPolicyViolation{Line: tok.Line, Message: "CRITICAL: collectgarbage() is forbidden — it masks memory leaks instead of fixing them"})
		}
		if policy.ForbidRequireInFunction && tok.Text == "require" && functionDepth2 > 0 && i+1 < len(tokens) && tokens[i+1].Kind == "symbol" && tokens[i+1].Text == "(" {
			violations = append(violations, luaPolicyViolation{Line: tok.Line, Message: "CRITICAL: require() inside a function causes memory leaks — move all require() calls to the top of the file"})
		}
		if policy.ForbidGlobalTable && tok.Text == "_G" {
			violations = append(violations, luaPolicyViolation{Line: tok.Line, Message: "CRITICAL: _G usage is forbidden — use the G module for shared state instead"})
		}
		if policy.ForbidCreateFontInFunction && strings.EqualFold(tok.Text, "draw") && functionDepth2 > 0 && i+3 < len(tokens) && tokens[i+1].Kind == "symbol" && tokens[i+1].Text == "." && strings.EqualFold(tokens[i+2].Text, "CreateFont") && tokens[i+3].Kind == "symbol" && tokens[i+3].Text == "(" {
			violations = append(violations, luaPolicyViolation{Line: tok.Line, Message: "CRITICAL: draw.CreateFont inside a function creates a permanent irremovable font on every call — move it to module-level (depth 0) and cache the handle"})
		}
		if policy.ForbidLegacyBitLibrary && strings.EqualFold(tok.Text, "bit") && i+3 < len(tokens) && tokens[i+1].Kind == "symbol" && tokens[i+1].Text == "." && tokens[i+2].Kind == "ident" && isLegacyBitMethod(tokens[i+2].Text) && tokens[i+3].Kind == "symbol" && tokens[i+3].Text == "(" {
			violations = append(violations, luaPolicyViolation{Line: tok.Line, Message: fmt.Sprintf("CRITICAL: bit.%s() does not exist in Lua 5.4 — use native bitwise operators instead", tokens[i+2].Text)})
		}
		if policy.ForbidAllowListener && tok.Text == "AllowListener" && i+1 < len(tokens) && tokens[i+1].Kind == "symbol" && tokens[i+1].Text == "(" {
			violations = append(violations, luaPolicyViolation{Line: tok.Line, Message: "CRITICAL: AllowListener() is deprecated and does nothing — remove the call"})
		}
		if policy.ForbidForceFullUpdate && tok.Text == "ForceFullUpdate" && i+1 < len(tokens) && tokens[i+1].Kind == "symbol" && tokens[i+1].Text == "(" {
			violations = append(violations, luaPolicyViolation{Line: tok.Line, Message: "CRITICAL: ForceFullUpdate() is dangerous and should be avoided — it can lag or crash the game if misused"})
		}
		if policy.ForbidWarpOutsideCreateMove && strings.EqualFold(tok.Text, "warp") && functionDepth2 == 0 && i+3 < len(tokens) && tokens[i+1].Kind == "symbol" && tokens[i+1].Text == "." && tokens[i+2].Kind == "ident" && isWarpTriggerMethod(tokens[i+2].Text) && tokens[i+3].Kind == "symbol" && tokens[i+3].Text == "(" {
			violations = append(violations, luaPolicyViolation{Line: tok.Line, Message: "CRITICAL: warp trigger calls must be made from a CreateMove callback only"})
		}
	}

	if policy.RequireDrawTextFontSetup && hasDrawText && !hasDrawSetFont {
		if line := findQualifiedCallLine(tokens, "draw", []string{"Text"}); line > 0 {
			violations = append(violations, luaPolicyViolation{Line: line, Message: "CRITICAL: draw.Text() requires draw.SetFont() to be called first or the script will error"})
		}
	}
	if policy.ForbidSuspiciousSetupBones {
		violations = append(violations, findSuspiciousSetupBonesViolations(content, tokens)...)
	}
	if policy.ForbidIpairsOnFindByClass {
		violations = append(violations, findIpairsOnFindByClassViolations(content)...)
	}

	return violations, nil
}

func hasQualifiedCall(tokens []luaToken, root string, method string) bool {
	return findQualifiedCallLine(tokens, root, []string{method}) > 0
}

func findQualifiedCallLine(tokens []luaToken, root string, methods []string) int {
	for i := 0; i+3 < len(tokens); i++ {
		if !(tokens[i].Kind == "ident" && strings.EqualFold(tokens[i].Text, root)) {
			continue
		}
		if tokens[i+1].Kind != "symbol" || tokens[i+1].Text != "." || tokens[i+2].Kind != "ident" {
			continue
		}
		matched := false
		for _, method := range methods {
			if strings.EqualFold(tokens[i+2].Text, method) {
				matched = true
				break
			}
		}
		if matched && tokens[i+3].Kind == "symbol" && tokens[i+3].Text == "(" {
			return tokens[i].Line
		}
	}
	return 0
}

func findQualifiedCallLineInArgs(args [][]luaToken, root string, methods []string) int {
	for _, arg := range args {
		if line := findQualifiedCallLine(arg, root, methods); line > 0 {
			return line
		}
	}
	return 0
}

func isLegacyBitMethod(name string) bool {
	switch strings.ToLower(name) {
	case "band", "bor", "bnot", "bxor", "lshift", "rshift", "arshift":
		return true
	default:
		return false
	}
}

func isWarpTriggerMethod(name string) bool {
	switch strings.ToLower(name) {
	case "triggerwarp", "triggerdoubletap", "triggercharge":
		return true
	default:
		return false
	}
}

func findSuspiciousSetupBonesViolations(content string, tokens []luaToken) []luaPolicyViolation {
	patterns := []struct {
		re      *regexp.Regexp
		message string
	}{
		{re: regexp.MustCompile(`(?m):SetupBones\s*\(\s*0\s*[,)]`), message: "CRITICAL: SetupBones with mask 0 returns no useful bones for hitbox work — use 0x7ff00"},
		{re: regexp.MustCompile(`(?m):SetupBones\s*\(\s*(?:255|0x0*ff)\s*[,)]`), message: "CRITICAL: SetupBones with mask 255 is too narrow for hitbox work — use 0x7ff00"},
	}

	violations := make([]luaPolicyViolation, 0)
	for _, pattern := range patterns {
		matches := pattern.re.FindAllStringIndex(content, -1)
		for _, match := range matches {
			violations = append(violations, luaPolicyViolation{Line: lineNumberForOffset(content, match[0]), Message: pattern.message})
		}
	}

	for i := 0; i+1 < len(tokens); i++ {
		if !(tokens[i].Kind == "ident" && strings.EqualFold(tokens[i].Text, "SetupBones")) {
			continue
		}
		if tokens[i+1].Kind != "symbol" || tokens[i+1].Text != "(" {
			continue
		}
		args, _ := collectLuaCallArgs(tokens, i+1)
		if len(args) == 0 {
			violations = append(violations, luaPolicyViolation{Line: tokens[i].Line, Message: "CRITICAL: SetupBones() should pass bone mask 0x7ff00 and globals.CurTime() — omitting both commonly returns incomplete or wrong data"})
			continue
		}
		if !argContainsQualifiedCall(args, "globals", "CurTime") {
			violations = append(violations, luaPolicyViolation{Line: tokens[i].Line, Message: "CRITICAL: SetupBones should use globals.CurTime() as the time argument — passing 0 or omitting time gives incorrect positions"})
		}
	}

	return dedupeLuaPolicyViolations(violations)
}

func argContainsQualifiedCall(args [][]luaToken, root string, method string) bool {
	return findQualifiedCallLineInArgs(args, root, []string{method}) > 0
}

func lineNumberForOffset(content string, offset int) int {
	if offset <= 0 {
		return 1
	}
	line := 1
	for i, r := range content {
		if i >= offset {
			break
		}
		if r == '\n' {
			line++
		}
	}
	return line
}

func dedupeLuaPolicyViolations(violations []luaPolicyViolation) []luaPolicyViolation {
	seen := make(map[string]bool, len(violations))
	out := make([]luaPolicyViolation, 0, len(violations))
	for _, violation := range violations {
		key := fmt.Sprintf("%d|%s", violation.Line, violation.Message)
		if !seen[key] {
			seen[key] = true
			out = append(out, violation)
		}
	}
	return out
}

func formatLuaPolicyViolations(filePath string, violations []luaPolicyViolation) string {
	var builder strings.Builder
	builder.WriteString("Zero-Mutation Lbox policy violation(s) detected:\n")
	builder.WriteString(fmt.Sprintf("file: %s\n", filePath))
	for _, violation := range violations {
		builder.WriteString(fmt.Sprintf("- line %d: %s\n", violation.Line, violation.Message))
	}
	return builder.String()
}

func findIpairsOnFindByClassViolations(content string) []luaPolicyViolation {
	lines := strings.Split(content, "\n")
	findByClassAssignRe := regexp.MustCompile(`^\s*(?:local\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*entities\s*\.\s*FindByClass\s*\(`)
	directIpairsRe := regexp.MustCompile(`ipairs\s*\(\s*entities\s*\.\s*FindByClass\s*\(`)
	ipairsVarRe := regexp.MustCompile(`ipairs\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)`)
	tableMutationRe := regexp.MustCompile(`table\s*\.\s*(?:insert|remove|sort)\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)\b`)

	sparseVars := make(map[string]bool)
	violations := make([]luaPolicyViolation, 0)

	for lineNumber, rawLine := range lines {
		line := rawLine

		if directIpairsRe.MatchString(line) {
			violations = append(violations, luaPolicyViolation{
				Line:    lineNumber + 1,
				Message: "CRITICAL: entities.FindByClass() returns a sparse entity table — do not iterate it with ipairs(); use pairs() unless you explicitly repack it first",
			})
		}

		if matches := findByClassAssignRe.FindStringSubmatch(line); len(matches) == 2 {
			sparseVars[matches[1]] = true
		}

		for _, matches := range ipairsVarRe.FindAllStringSubmatch(line, -1) {
			if len(matches) == 2 && sparseVars[matches[1]] {
				violations = append(violations, luaPolicyViolation{
					Line:    lineNumber + 1,
					Message: fmt.Sprintf("CRITICAL: %s comes directly from entities.FindByClass() and may be sparse — use pairs(%s) unless you explicitly rebuilt it into a sequential array first", matches[1], matches[1]),
				})
			}
		}

		for varName := range sparseVars {
			reassignRe := regexp.MustCompile(fmt.Sprintf(`^\s*(?:local\s+)?%s\s*=`, regexp.QuoteMeta(varName)))
			indexMutationRe := regexp.MustCompile(fmt.Sprintf(`\b%s\s*\[.*\]\s*=`, regexp.QuoteMeta(varName)))
			if reassignRe.MatchString(line) && !findByClassAssignRe.MatchString(line) {
				delete(sparseVars, varName)
				continue
			}
			if indexMutationRe.MatchString(line) {
				delete(sparseVars, varName)
				continue
			}
		}

		for _, matches := range tableMutationRe.FindAllStringSubmatch(line, -1) {
			if len(matches) == 2 {
				delete(sparseVars, matches[1])
			}
		}
	}

	return dedupeLuaPolicyViolations(violations)
}
