FROM golang:alpine AS builder
WORKDIR /build
COPY go.mod .
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags '-extldflags "-static"' -o main .

FROM scratch
WORKDIR /app
COPY --from=builder /build/main /app/
ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["./main"]