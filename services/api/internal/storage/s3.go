package storage

import (
	"context"
	"fmt"
	"io"
	"net/url"
	"strings"
	"time"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

type Client struct {
	internal *minio.Client
	presign  *minio.Client
	bucket   string
}

type Config struct {
	Endpoint        string
	PublicEndpoint  string
	AccessKey       string
	SecretKey       string
	Bucket          string
	Region          string
	UseSSL          bool
	PublicUseSSL    bool
}

func New(ctx context.Context, cfg Config) (*Client, error) {
	if cfg.Bucket == "" {
		cfg.Bucket = "jobsiterecords"
	}
	if cfg.Region == "" {
		cfg.Region = "us-east-1"
	}
	public := cfg.PublicEndpoint
	if public == "" {
		public = cfg.Endpoint
	}

	internal, err := minio.New(cfg.Endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.AccessKey, cfg.SecretKey, ""),
		Secure: cfg.UseSSL,
		Region: cfg.Region,
	})
	if err != nil {
		return nil, fmt.Errorf("s3 internal client: %w", err)
	}

	presign, err := minio.New(public, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.AccessKey, cfg.SecretKey, ""),
		Secure: cfg.PublicUseSSL,
		Region: cfg.Region,
	})
	if err != nil {
		return nil, fmt.Errorf("s3 presign client: %w", err)
	}

	c := &Client{internal: internal, presign: presign, bucket: cfg.Bucket}
	if err := c.ensureBucket(ctx); err != nil {
		return nil, err
	}
	return c, nil
}

func (c *Client) ensureBucket(ctx context.Context) error {
	exists, err := c.internal.BucketExists(ctx, c.bucket)
	if err != nil {
		return err
	}
	if !exists {
		if err := c.internal.MakeBucket(ctx, c.bucket, minio.MakeBucketOptions{}); err != nil {
			return err
		}
	}
	return nil
}

func (c *Client) PresignedPut(ctx context.Context, key, contentType string, ttl time.Duration) (string, error) {
	u, err := c.presign.PresignedPutObject(ctx, c.bucket, key, ttl)
	if err != nil {
		return "", err
	}
	return u.String(), nil
}

func (c *Client) PresignedGet(ctx context.Context, key string, ttl time.Duration) (string, error) {
	reqParams := make(url.Values)
	u, err := c.presign.PresignedGetObject(ctx, c.bucket, key, ttl, reqParams)
	if err != nil {
		return "", err
	}
	return u.String(), nil
}

type ObjectMeta struct {
	Size    int64
	ETag    string
	Content string
}

func (c *Client) Head(ctx context.Context, key string) (ObjectMeta, error) {
	info, err := c.internal.StatObject(ctx, c.bucket, key, minio.StatObjectOptions{})
	if err != nil {
		return ObjectMeta{}, err
	}
	return ObjectMeta{
		Size:    info.Size,
		ETag:    strings.Trim(info.ETag, `"`),
		Content: info.ContentType,
	}, nil
}

func (c *Client) Get(ctx context.Context, key string) ([]byte, error) {
	obj, err := c.internal.GetObject(ctx, c.bucket, key, minio.GetObjectOptions{})
	if err != nil {
		return nil, err
	}
	defer obj.Close()
	return io.ReadAll(obj)
}

func (c *Client) Put(ctx context.Context, key, contentType string, body io.Reader, size int64) error {
	_, err := c.internal.PutObject(ctx, c.bucket, key, body, size, minio.PutObjectOptions{
		ContentType: contentType,
	})
	return err
}
