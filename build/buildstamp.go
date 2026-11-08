package version

import "time"

// buildVCSTime is the release commit time (RFC 3339), set with -ldflags -X. This image is built from
// the source archive with -buildvcs=false, so Go records no VCS stamp; the official build reads the
// same commit time from that stamp. The commit itself is set the same way, through vcsRevision.
var buildVCSTime string

func init() {
	if t, err := time.Parse(time.RFC3339, buildVCSTime); err == nil {
		vcsTime = t
	}
}
