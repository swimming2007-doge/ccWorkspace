/**
 * 华为云OBS存储服务
 *
 * 功能说明：
 * - 文件上传到OBS
 * - 文件下载
 * - 断点续传支持
 * - 签名URL生成
 */

import crypto from 'crypto';
import https from 'https';
import http from 'http';
import { URL } from 'url';
import fs from 'fs';
import path from 'path';

// OBS配置
interface OBSConfig {
  accessKeyId: string;
  secretAccessKey: string;
  endpoint: string;
  bucket: string;
  region: string;
}

// 上传选项
interface UploadOptions {
  key: string;
  body: Buffer | string;
  contentType?: string;
  metadata?: Record<string, string>;
}

// 上传结果
interface UploadResult {
  location: string;
  key: string;
  etag: string;
}

// 分片上传信息
interface MultipartUpload {
  uploadId: string;
  key: string;
  bucket: string;
  parts: UploadedPart[];
}

interface UploadedPart {
  partNumber: number;
  etag: string;
}

/**
 * OBS存储服务类
 */
export class OBSService {
  private config: OBSConfig;

  constructor(config?: Partial<OBSConfig>) {
    this.config = {
      accessKeyId: config?.accessKeyId || process.env.OBS_ACCESS_KEY_ID || '',
      secretAccessKey: config?.secretAccessKey || process.env.OBS_SECRET_ACCESS_KEY || '',
      endpoint: config?.endpoint || process.env.OBS_ENDPOINT || 'obs.cn-north-4.myhuaweicloud.com',
      bucket: config?.bucket || process.env.OBS_BUCKET || 'riderecord',
      region: config?.region || process.env.OBS_REGION || 'cn-north-4'
    };
  }

  /**
   * 上传文件
   */
  async upload(options: UploadOptions): Promise<UploadResult> {
    const { key, body, contentType = 'application/octet-stream', metadata = {} } = options;

    const bodyBuffer = typeof body === 'string' ? Buffer.from(body) : body;
    const contentMd5 = this.calculateMD5(bodyBuffer);
    const date = new Date().toUTCString();

    // 构建签名
    const stringToSign = this.buildStringToSign('PUT', key, {
      'Content-Type': contentType,
      'Content-MD5': contentMd5,
      'Date': date,
      ...Object.fromEntries(
        Object.entries(metadata).map(([k, v]) => [`x-obs-meta-${k}`, v])
      )
    });

    const signature = this.sign(stringToSign);
    const authorization = `OBS ${this.config.accessKeyId}:${signature}`;

    const url = `https://${this.config.bucket}.${this.config.endpoint}/${key}`;

    return new Promise((resolve, reject) => {
      const req = https.request(url, {
        method: 'PUT',
        headers: {
          'Content-Type': contentType,
          'Content-MD5': contentMd5,
          'Date': date,
          'Authorization': authorization,
          'Content-Length': bodyBuffer.length,
          ...Object.fromEntries(
            Object.entries(metadata).map(([k, v]) => [`x-obs-meta-${k}`, v])
          )
        }
      }, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          if (res.statusCode && res.statusCode >= 200 && res.statusCode < 300) {
            const etag = res.headers.etag?.replace(/"/g, '') || '';
            resolve({
              location: url,
              key,
              etag
            });
          } else {
            reject(new Error(`Upload failed: ${res.statusCode} - ${data}`));
          }
        });
      });

      req.on('error', reject);
      req.write(bodyBuffer);
      req.end();
    });
  }

  /**
   * 初始化分片上传
   */
  async initMultipartUpload(key: string, metadata: Record<string, string> = {}): Promise<string> {
    const date = new Date().toUTCString();

    const stringToSign = this.buildStringToSign('POST', key, {
      'Date': date,
      ...Object.fromEntries(
        Object.entries(metadata).map(([k, v]) => [`x-obs-meta-${k}`, v])
      )
    });

    const signature = this.sign(stringToSign);
    const authorization = `OBS ${this.config.accessKeyId}:${signature}`;

    const url = `https://${this.config.bucket}.${this.config.endpoint}/${key}?uploads`;

    return new Promise((resolve, reject) => {
      const req = https.request(url, {
        method: 'POST',
        headers: {
          'Date': date,
          'Authorization': authorization
        }
      }, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          if (res.statusCode === 200) {
            // 解析XML获取uploadId
            const match = data.match(/<UploadId>([^<]+)<\/UploadId>/);
            if (match) {
              resolve(match[1]);
            } else {
              reject(new Error('Failed to parse uploadId'));
            }
          } else {
            reject(new Error(`Init multipart upload failed: ${res.statusCode}`));
          }
        });
      });

      req.on('error', reject);
      req.end();
    });
  }

  /**
   * 上传分片
   */
  async uploadPart(
    key: string,
    uploadId: string,
    partNumber: number,
    body: Buffer
  ): Promise<{ etag: string; partNumber: number }> {
    const contentMd5 = this.calculateMD5(body);
    const date = new Date().toUTCString();

    const stringToSign = this.buildStringToSign('PUT', key, {
      'Content-MD5': contentMd5,
      'Date': date
    });

    const signature = this.sign(stringToSign);
    const authorization = `OBS ${this.config.accessKeyId}:${signature}`;

    const url = `https://${this.config.bucket}.${this.config.endpoint}/${key}?partNumber=${partNumber}&uploadId=${uploadId}`;

    return new Promise((resolve, reject) => {
      const req = https.request(url, {
        method: 'PUT',
        headers: {
          'Content-MD5': contentMd5,
          'Date': date,
          'Authorization': authorization,
          'Content-Length': body.length
        }
      }, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          if (res.statusCode && res.statusCode >= 200 && res.statusCode < 300) {
            const etag = res.headers.etag?.replace(/"/g, '') || '';
            resolve({ etag, partNumber });
          } else {
            reject(new Error(`Upload part failed: ${res.statusCode}`));
          }
        });
      });

      req.on('error', reject);
      req.write(body);
      req.end();
    });
  }

  /**
   * 完成分片上传
   */
  async completeMultipartUpload(
    key: string,
    uploadId: string,
    parts: UploadedPart[]
  ): Promise<UploadResult> {
    const date = new Date().toUTCString();

    // 构建完成分片上传的XML
    const partsXml = parts
      .sort((a, b) => a.partNumber - b.partNumber)
      .map(p => `<Part><PartNumber>${p.partNumber}</PartNumber><ETag>"${p.etag}"</ETag></Part>`)
      .join('');

    const body = `<CompleteMultipartUpload>${partsXml}</CompleteMultipartUpload>`;
    const bodyBuffer = Buffer.from(body);

    const stringToSign = this.buildStringToSign('POST', key, {
      'Date': date,
      'Content-Length': bodyBuffer.length.toString()
    });

    const signature = this.sign(stringToSign);
    const authorization = `OBS ${this.config.accessKeyId}:${signature}`;

    const url = `https://${this.config.bucket}.${this.config.endpoint}/${key}?uploadId=${uploadId}`;

    return new Promise((resolve, reject) => {
      const req = https.request(url, {
        method: 'POST',
        headers: {
          'Date': date,
          'Authorization': authorization,
          'Content-Type': 'application/xml',
          'Content-Length': bodyBuffer.length
        }
      }, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          if (res.statusCode === 200) {
            const locationMatch = data.match(/<Location>([^<]+)<\/Location>/);
            const etagMatch = data.match(/<ETag>"?([^"<]+)"?<\/ETag>/);

            resolve({
              location: locationMatch ? decodeURIComponent(locationMatch[1]) : '',
              key,
              etag: etagMatch ? etagMatch[1] : ''
            });
          } else {
            reject(new Error(`Complete multipart upload failed: ${res.statusCode}`));
          }
        });
      });

      req.on('error', reject);
      req.write(bodyBuffer);
      req.end();
    });
  }

  /**
   * 生成签名URL (临时访问)
   */
  getSignedUrl(key: string, expiresIn: number = 3600): string {
    const expires = Math.floor(Date.now() / 1000) + expiresIn;

    const stringToSign = this.buildStringToSign('GET', key, {
      'Expires': expires.toString()
    });

    const signature = this.sign(stringToSign);
    const encodedSignature = encodeURIComponent(signature);

    return `https://${this.config.bucket}.${this.config.endpoint}/${key}?AWSAccessKeyId=${this.config.accessKeyId}&Expires=${expires}&Signature=${encodedSignature}`;
  }

  /**
   * 删除文件
   */
  async delete(key: string): Promise<void> {
    const date = new Date().toUTCString();

    const stringToSign = this.buildStringToSign('DELETE', key, {
      'Date': date
    });

    const signature = this.sign(stringToSign);
    const authorization = `OBS ${this.config.accessKeyId}:${signature}`;

    const url = `https://${this.config.bucket}.${this.config.endpoint}/${key}`;

    return new Promise((resolve, reject) => {
      const req = https.request(url, {
        method: 'DELETE',
        headers: {
          'Date': date,
          'Authorization': authorization
        }
      }, (res) => {
        if (res.statusCode && res.statusCode >= 200 && res.statusCode < 300) {
          resolve();
        } else {
          reject(new Error(`Delete failed: ${res.statusCode}`));
        }
      });

      req.on('error', reject);
      req.end();
    });
  }

  /**
   * 检查文件是否存在
   */
  async exists(key: string): Promise<boolean> {
    const date = new Date().toUTCString();

    const stringToSign = this.buildStringToSign('HEAD', key, {
      'Date': date
    });

    const signature = this.sign(stringToSign);
    const authorization = `OBS ${this.config.accessKeyId}:${signature}`;

    const url = `https://${this.config.bucket}.${this.config.endpoint}/${key}`;

    return new Promise((resolve) => {
      const req = https.request(url, {
        method: 'HEAD',
        headers: {
          'Date': date,
          'Authorization': authorization
        }
      }, (res) => {
        resolve(res.statusCode === 200);
      });

      req.on('error', () => resolve(false));
      req.end();
    });
  }

  // ==================== 私有方法 ====================

  /**
   * 计算MD5
   */
  private calculateMD5(data: Buffer): string {
    return crypto.createHash('md5').update(data).digest('base64');
  }

  /**
   * 构建签名字符串
   */
  private buildStringToSign(
    method: string,
    key: string,
    headers: Record<string, string | number>
  ): string {
    const canonicalizedHeaders = Object.entries(headers)
      .filter(([k]) => k.toLowerCase().startsWith('x-obs-'))
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([k, v]) => `${k.toLowerCase()}:${v}`)
      .join('\n');

    const contentType = headers['Content-Type'] || '';
    const contentMd5 = headers['Content-MD5'] || '';
    const date = headers['Date'] || '';
    const expires = headers['Expires'] || '';

    let stringToSign = `${method}\n${contentMd5}\n${contentType}\n${expires || date}\n`;

    if (canonicalizedHeaders) {
      stringToSign += canonicalizedHeaders + '\n';
    }

    stringToSign += `/${this.config.bucket}/${key}`;

    return stringToSign;
  }

  /**
   * 签名
   */
  private sign(stringToSign: string): string {
    return crypto
      .createHmac('sha1', this.config.secretAccessKey)
      .update(stringToSign)
      .digest('base64');
  }
}

// 导出单例
export const obsService = new OBSService();
export default obsService;
