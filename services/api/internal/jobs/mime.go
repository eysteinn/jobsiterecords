package jobs

import (
	"bytes"
	"errors"
	"strings"
)

const MaxBlobBytes = 50 * 1024 * 1024
const MaxVoiceDurationMs = 10 * 60 * 1000

var allowedPhotoMimes = map[string]bool{
	"image/jpeg": true,
	"image/png":  true,
	"image/heic": true,
	"image/heif": true,
	"image/webp": true,
}

var allowedVoiceMimes = map[string]bool{
	"audio/m4a":   true,
	"audio/mp4":   true,
	"audio/aac":   true,
	"audio/wav":   true,
	"audio/webm":  true,
	"audio/x-m4a": true,
}

var allowedFileMimes = map[string]bool{
	"application/pdf":  true,
	"application/json": true,
	"text/plain":       true,
	"text/csv":         true,
}

func mimeAllowed(mime string) bool {
	mime = strings.ToLower(strings.TrimSpace(mime))
	if allowedPhotoMimes[mime] || allowedVoiceMimes[mime] || allowedFileMimes[mime] {
		return true
	}
	return strings.HasPrefix(mime, "image/") && allowedPhotoMimes[mime]
}

func validateMagicBytes(mime string, head []byte) error {
	mime = strings.ToLower(strings.TrimSpace(mime))
	switch {
	case mime == "image/jpeg" || mime == "image/jpg":
		if len(head) >= 3 && head[0] == 0xFF && head[1] == 0xD8 && head[2] == 0xFF {
			return nil
		}
	case mime == "image/png":
		if len(head) >= 8 && bytes.Equal(head[:8], []byte{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A}) {
			return nil
		}
	case mime == "application/pdf":
		if len(head) >= 4 && string(head[:4]) == "%PDF" {
			return nil
		}
	case strings.HasPrefix(mime, "audio/"):
		if len(head) >= 12 && string(head[4:8]) == "ftyp" {
			return nil
		}
		if mime == "audio/webm" && len(head) >= 4 && head[0] == 0x1A && head[1] == 0x45 && head[2] == 0xDF && head[3] == 0xA3 {
			return nil
		}
		if mime == "audio/wav" && len(head) >= 12 && string(head[:4]) == "RIFF" && string(head[8:12]) == "WAVE" {
			return nil
		}
	case mime == "application/json":
		trimmed := bytes.TrimSpace(head)
		if len(trimmed) == 0 || trimmed[0] == '{' || trimmed[0] == '[' {
			return nil
		}
	case mime == "text/plain" || mime == "text/csv":
		return nil
	case strings.HasPrefix(mime, "image/"):
		// Accept other declared image types without deep validation in MVP.
		return nil
	}
	return errors.New("mime mismatch")
}
