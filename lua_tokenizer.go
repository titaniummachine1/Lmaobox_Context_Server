package main

import "strings"

type luaToken struct {
	Kind string
	Text string
	Line int
}

func extractCallbacksCall(tokens []luaToken, start int) (string, [][]luaToken, int, bool) {
	if start+3 >= len(tokens) {
		return "", nil, start, false
	}
	if !(tokens[start].Kind == "ident" && strings.EqualFold(tokens[start].Text, "callbacks")) {
		return "", nil, start, false
	}
	if tokens[start+1].Kind != "symbol" || tokens[start+1].Text != "." {
		return "", nil, start, false
	}
	if tokens[start+2].Kind != "ident" {
		return "", nil, start, false
	}
	method := strings.ToLower(tokens[start+2].Text)
	if method != "register" && method != "unregister" {
		return "", nil, start, false
	}
	if tokens[start+3].Kind != "symbol" || tokens[start+3].Text != "(" {
		return "", nil, start, false
	}
	args, endIndex := collectLuaCallArgs(tokens, start+3)
	if endIndex <= start+3 {
		return "", nil, start, false
	}
	return method, args, endIndex, true
}

func collectLuaCallArgs(tokens []luaToken, openParenIndex int) ([][]luaToken, int) {
	args := make([][]luaToken, 0)
	currentArg := make([]luaToken, 0)
	parenDepth := 0
	braceDepth := 0
	bracketDepth := 0

	for i := openParenIndex; i < len(tokens); i++ {
		tok := tokens[i]
		if tok.Kind == "symbol" {
			switch tok.Text {
			case "(":
				parenDepth++
				if parenDepth > 1 {
					currentArg = append(currentArg, tok)
				}
				continue
			case ")":
				if parenDepth == 1 {
					trimmed := trimLuaArgTokens(currentArg)
					if len(trimmed) > 0 {
						args = append(args, trimmed)
					}
					return args, i
				}
				if parenDepth > 1 {
					currentArg = append(currentArg, tok)
				}
				if parenDepth > 0 {
					parenDepth--
				}
				continue
			case "{":
				if parenDepth >= 1 {
					braceDepth++
					currentArg = append(currentArg, tok)
					continue
				}
			case "}":
				if parenDepth >= 1 {
					if braceDepth > 0 {
						braceDepth--
					}
					currentArg = append(currentArg, tok)
					continue
				}
			case "[":
				if parenDepth >= 1 {
					bracketDepth++
					currentArg = append(currentArg, tok)
					continue
				}
			case "]":
				if parenDepth >= 1 {
					if bracketDepth > 0 {
						bracketDepth--
					}
					currentArg = append(currentArg, tok)
					continue
				}
			case ",":
				if parenDepth == 1 && braceDepth == 0 && bracketDepth == 0 {
					args = append(args, trimLuaArgTokens(currentArg))
					currentArg = make([]luaToken, 0)
					continue
				}
			}
		}
		if parenDepth >= 1 {
			currentArg = append(currentArg, tok)
		}
	}

	return args, openParenIndex
}

func trimLuaArgTokens(arg []luaToken) []luaToken {
	if len(arg) == 0 {
		return arg
	}
	start := 0
	end := len(arg)
	for start < end && arg[start].Kind == "whitespace" {
		start++
	}
	for end > start && arg[end-1].Kind == "whitespace" {
		end--
	}
	if start >= end {
		return []luaToken{}
	}
	return arg[start:end]
}

func stringArgValue(args [][]luaToken, index int) string {
	if index < 0 || index >= len(args) {
		return ""
	}
	arg := args[index]
	if len(arg) != 1 || arg[0].Kind != "string" {
		return ""
	}
	return arg[0].Text
}

func tokenizeLua(content string) ([]luaToken, error) {
	tokens := make([]luaToken, 0, len(content)/3)
	runes := []rune(content)
	line := 1

	for i := 0; i < len(runes); {
		ch := runes[i]
		if ch == '\n' {
			line++
			i++
			continue
		}
		if ch == ' ' || ch == '\t' || ch == '\r' {
			i++
			continue
		}
		if ch == '-' && i+1 < len(runes) && runes[i+1] == '-' {
			i += 2
			if openLen, ok := detectLuaLongBracketOpen(runes, i); ok {
				i += openLen
				for i < len(runes) {
					if runes[i] == '\n' {
						line++
					}
					if closeLen, closed := detectLuaLongBracketClose(runes, i, openLen); closed {
						i += closeLen
						break
					}
					i++
				}
				continue
			}
			for i < len(runes) && runes[i] != '\n' {
				i++
			}
			continue
		}
		if ch == '\'' || ch == '"' {
			quote := ch
			startLine := line
			i++
			var builder strings.Builder
			for i < len(runes) {
				if runes[i] == '\n' {
					line++
				}
				if runes[i] == '\\' && i+1 < len(runes) {
					builder.WriteRune(runes[i])
					builder.WriteRune(runes[i+1])
					i += 2
					continue
				}
				if runes[i] == quote {
					i++
					break
				}
				builder.WriteRune(runes[i])
				i++
			}
			tokens = append(tokens, luaToken{Kind: "string", Text: builder.String(), Line: startLine})
			continue
		}
		if openLen, ok := detectLuaLongBracketOpen(runes, i); ok {
			startLine := line
			i += openLen
			var builder strings.Builder
			for i < len(runes) {
				if runes[i] == '\n' {
					line++
				}
				if closeLen, closed := detectLuaLongBracketClose(runes, i, openLen); closed {
					i += closeLen
					break
				}
				builder.WriteRune(runes[i])
				i++
			}
			tokens = append(tokens, luaToken{Kind: "string", Text: builder.String(), Line: startLine})
			continue
		}
		if isLuaIdentifierStart(ch) {
			start := i
			startLine := line
			i++
			for i < len(runes) && isLuaIdentifierPart(runes[i]) {
				i++
			}
			text := string(runes[start:i])
			kind := "ident"
			if isLuaKeyword(text) {
				kind = "keyword"
			}
			tokens = append(tokens, luaToken{Kind: kind, Text: text, Line: startLine})
			continue
		}
		if ch == '.' || ch == '(' || ch == ')' || ch == ',' || ch == '{' || ch == '}' || ch == '[' || ch == ']' {
			tokens = append(tokens, luaToken{Kind: "symbol", Text: string(ch), Line: line})
			i++
			continue
		}
		i++
	}

	return tokens, nil
}

func detectLuaLongBracketOpen(runes []rune, index int) (int, bool) {
	if index >= len(runes) || runes[index] != '[' {
		return 0, false
	}
	i := index + 1
	for i < len(runes) && runes[i] == '=' {
		i++
	}
	if i < len(runes) && runes[i] == '[' {
		return i - index + 1, true
	}
	return 0, false
}

func detectLuaLongBracketClose(runes []rune, index, openLen int) (int, bool) {
	if index >= len(runes) || runes[index] != ']' {
		return 0, false
	}
	eqCount := openLen - 2
	if eqCount < 0 {
		eqCount = 0
	}
	i := index + 1
	for j := 0; j < eqCount; j++ {
		if i >= len(runes) || runes[i] != '=' {
			return 0, false
		}
		i++
	}
	if i < len(runes) && runes[i] == ']' {
		return i - index + 1, true
	}
	return 0, false
}

func isLuaIdentifierStart(ch rune) bool {
	return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '_'
}

func isLuaIdentifierPart(ch rune) bool {
	return isLuaIdentifierStart(ch) || (ch >= '0' && ch <= '9')
}

func isLuaKeyword(text string) bool {
	switch text {
	case "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while":
		return true
	default:
		return false
	}
}
