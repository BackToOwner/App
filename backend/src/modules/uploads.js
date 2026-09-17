import multer from 'multer';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { ApiError } from '../utils/ApiError.js';
import { uploadsDir } from '../config/paths.js';

const ALLOWED_EXTENSIONS = new Set(['.jpg', '.jpeg', '.png', '.webp']);
const ALLOWED_MIME = new Set(['image/jpeg', 'image/png', 'image/webp']);

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadsDir),
  filename: (req, file, cb) => {
    // Randomised name: the client's filename is attacker-controlled and must never reach the
    // filesystem (path traversal, collisions, leaking the uploader's local paths).
    const ext = path.extname(file.originalname).toLowerCase();
    cb(null, `${Date.now()}-${crypto.randomBytes(8).toString('hex')}${ALLOWED_EXTENSIONS.has(ext) ? ext : '.jpg'}`);
  },
});

function fileFilter(req, file, cb) {
  const ext = path.extname(file.originalname).toLowerCase();
  if (!ALLOWED_EXTENSIONS.has(ext) || !ALLOWED_MIME.has(file.mimetype)) {
    return cb(new ApiError(400, 'Only JPG, PNG and WebP images are allowed'));
  }
  cb(null, true);
}

const limits = { fileSize: 5 * 1024 * 1024, files: 5 };

export const uploadSingleImage = multer({ storage, fileFilter, limits }).single('image');
export const uploadReportImages = multer({ storage, fileFilter, limits }).array('images', 5);

/**
 * The extension and MIME checks above trust headers the client controls. This verifies the bytes
 * actually written to disk and deletes anything that is not a real image, so a .jpg full of
 * script never survives the request that uploaded it.
 */
const MAGIC = [
  { ext: 'jpg', bytes: [0xff, 0xd8, 0xff] },
  { ext: 'png', bytes: [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a] },
  { ext: 'webp', bytes: [0x52, 0x49, 0x46, 0x46] }, // 'RIFF', with 'WEBP' at offset 8
];

function looksLikeImage(filePath) {
  let fd;
  try {
    fd = fs.openSync(filePath, 'r');
    const header = Buffer.alloc(12);
    fs.readSync(fd, header, 0, 12, 0);
    for (const { ext, bytes } of MAGIC) {
      if (bytes.every((byte, i) => header[i] === byte)) {
        if (ext === 'webp') return header.subarray(8, 12).toString('ascii') === 'WEBP';
        return true;
      }
    }
    return false;
  } catch {
    return false;
  } finally {
    if (fd !== undefined) fs.closeSync(fd);
  }
}

export function verifyUploadedImages(req, res, next) {
  const files = req.files || (req.file ? [req.file] : []);
  const bad = files.filter((file) => !looksLikeImage(file.path));
  if (bad.length > 0) {
    for (const file of files) fs.rmSync(file.path, { force: true });
    return next(new ApiError(400, 'Upload rejected: the file contents are not a valid JPG, PNG or WebP image'));
  }
  next();
}

// Turns multer's own errors into the API's error envelope.
export function handleUploadErrors(err, req, res, next) {
  if (err instanceof multer.MulterError) {
    const message =
      err.code === 'LIMIT_FILE_SIZE'
        ? 'Each image must be 5 MB or smaller'
        : err.code === 'LIMIT_FILE_COUNT' || err.code === 'LIMIT_UNEXPECTED_FILE'
          ? 'At most 5 images can be uploaded at once'
          : `Upload failed: ${err.message}`;
    return next(new ApiError(400, message));
  }
  next(err);
}
