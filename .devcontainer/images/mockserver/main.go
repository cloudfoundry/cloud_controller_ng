package main

import (
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"os"

	"code.cloudfoundry.org/bbs/models"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"

	"github.com/labstack/gommon/log"
)

func main() {
	e := echo.New()
	e.Logger.SetLevel(log.DEBUG)

	diegoURL, err := url.Parse(os.Getenv("DIEGO_URL"))
	if err != nil {
		e.Logger.Fatal(err)
	}

	caCert, err := os.ReadFile(os.Getenv("DIEGO_CA"))
	if err != nil {
		e.Logger.Fatal(err)
	}
	caCertPool := x509.NewCertPool()
	caCertPool.AppendCertsFromPEM(caCert)

	cert, err := tls.LoadX509KeyPair(os.Getenv("DIEGO_CLIENT_CERT"), os.Getenv("DIEGO_CLIENT_KEY"))
	if err != nil {
		e.Logger.Fatal(err)
	}

	e.Use(middleware.Logger())
	e.Use(middleware.BodyDump(func(c echo.Context, reqBody, resBody []byte) {
		switch c.Request().URL.String() {
		case "/v1/tasks/desire.r2":
			taskReq := &models.DesireTaskRequest{}
			err := taskReq.Unmarshal(reqBody)
			if err != nil {
				c.Logger().Error(err)
			}

			taskReqJSON, err := json.Marshal(taskReq)
			if err != nil {
				c.Logger().Error(err)
			}

			fmt.Println(string(taskReqJSON))
		default:
			c.Logger().Debug(string(reqBody))
		}
	}))

	// Mock auctioneer
	e.POST("/v1/tasks", func(c echo.Context) error {
		return c.NoContent(http.StatusAccepted)
	})

	// Proxy the rest to the Diego API
	e.Group("/*", middleware.ProxyWithConfig(middleware.ProxyConfig{
		Balancer: middleware.NewRandomBalancer([]*middleware.ProxyTarget{
			{
				Name: "diego-api",
				URL:  diegoURL,
			},
		}),
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{
				InsecureSkipVerify: true,
				RootCAs:            caCertPool,
				Certificates:       []tls.Certificate{cert},
			},
		},
	}))

	e.Logger.Fatal(e.Start(":1234"))
}
