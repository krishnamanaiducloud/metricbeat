// Package godror stands in for github.com/godror/godror in this static (CGO_ENABLED=0) Metricbeat build.
//
// The real driver is a cgo binding to Oracle's ODPI-C and cannot be compiled without cgo. Metricbeat
// only uses its DSN helpers, which come unchanged from the real godror/dsn package, and the "godror"
// database/sql driver name. Opening a connection reports that the Oracle client is unavailable, the
// same result the official image gives when Oracle Instant Client is not installed.
package godror

import (
	"context"
	"database/sql"
	"database/sql/driver"
	"errors"

	"github.com/godror/godror/dsn"
)

type (
	ConnectionParams = dsn.ConnectionParams
	CommonParams     = dsn.CommonParams
	ConnParams       = dsn.ConnParams
	PoolParams       = dsn.PoolParams
	Password         = dsn.Password
)

// ErrNoOracleClient is returned for every connection attempt.
var ErrNoOracleClient = errors.New("godror: cannot connect to Oracle: this static Metricbeat build has no Oracle client library (ODPI-C needs cgo)")

// ParseDSN parses an Oracle data source name with the real godror/dsn parser.
func ParseDSN(dataSourceName string) (ConnectionParams, error) { return dsn.Parse(dataSourceName) }

// ParseConnString is the deprecated alias of ParseDSN.
func ParseConnString(s string) (ConnectionParams, error) { return dsn.Parse(s) }

// Bool is a helper for sql.NullBool.
func Bool(b bool) sql.NullBool { return dsn.Bool(b) }

// NewPassword wraps a password so it is not printed.
func NewPassword(s string) Password { return dsn.NewPassword(s) }

type unavailableDriver struct{}

func (unavailableDriver) Open(string) (driver.Conn, error) { return nil, ErrNoOracleClient }

func (unavailableDriver) OpenConnector(string) (driver.Connector, error) {
	return unavailableConnector{}, nil
}

type unavailableConnector struct{}

func (unavailableConnector) Connect(context.Context) (driver.Conn, error) { return nil, ErrNoOracleClient }

func (unavailableConnector) Driver() driver.Driver { return unavailableDriver{} }

func init() { sql.Register("godror", unavailableDriver{}) }
