FROM golang:1.22-alpine AS build
WORKDIR /app
COPY go.mod ./
RUN go mod download
COPY *.go ./
RUN CGO_ENABLED=0 go build -o /stripe-webhook-router .

FROM alpine:3.20
RUN apk add --no-cache ca-certificates
COPY --from=build /stripe-webhook-router /stripe-webhook-router
COPY config.json /config.json
ENV CONFIG_PATH=/config.json
EXPOSE 8080
ENTRYPOINT ["/stripe-webhook-router"]
