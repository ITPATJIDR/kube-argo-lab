FROM docker.io/library/golang:1.23-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY *.go ./
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /auth .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /auth /auth
EXPOSE 8080
USER nonroot
ENTRYPOINT ["/auth"]
