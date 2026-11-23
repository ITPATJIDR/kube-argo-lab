// auth service: issues and verifies HMAC-signed tokens for demo users.
package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"
)

// Demo users — lab only.
var users = map[string]string{
	"alice": "alice123",
	"bob":   "bob123",
}

var secret = []byte(getenv("AUTH_SECRET", "dev-secret-change-me"))

const tokenTTL = time.Hour

func getenv(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func sign(payload string) string {
	m := hmac.New(sha256.New, secret)
	m.Write([]byte(payload))
	return base64.RawURLEncoding.EncodeToString(m.Sum(nil))
}

// token = base64(user:expiryUnix) + "." + hmac
func issueToken(user string) string {
	payload := base64.RawURLEncoding.EncodeToString(
		[]byte(fmt.Sprintf("%s:%d", user, time.Now().Add(tokenTTL).Unix())))
	return payload + "." + sign(payload)
}

func verifyToken(tok string) (string, bool) {
	payload, sig, ok := strings.Cut(tok, ".")
	if !ok || !hmac.Equal([]byte(sig), []byte(sign(payload))) {
		return "", false
	}
	raw, err := base64.RawURLEncoding.DecodeString(payload)
	if err != nil {
		return "", false
	}
	user, expStr, ok := strings.Cut(string(raw), ":")
	exp, err := strconv.ParseInt(expStr, 10, 64)
	if !ok || err != nil || time.Now().Unix() > exp {
		return "", false
	}
	return user, true
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func login(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	pw, ok := users[req.Username]
	if !ok || !hmac.Equal([]byte(pw), []byte(req.Password)) {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "invalid credentials"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"token":      issueToken(req.Username),
		"username":   req.Username,
		"expires_in": int(tokenTTL.Seconds()),
	})
}

func verify(w http.ResponseWriter, r *http.Request) {
	tok, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "missing bearer token"})
		return
	}
	user, valid := verifyToken(tok)
	if !valid {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "invalid or expired token"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"username": user})
}

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("POST /api/auth/login", login)
	mux.HandleFunc("GET /api/auth/verify", verify)
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok", "service": "auth"})
	})

	addr := ":" + getenv("PORT", "8080")
	log.Printf("auth listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, mux))
}
