import { common } from '@kit.AbilityKit';
import fs from '@ohos.file.fs';
import image from '@ohos.multimedia.image';
import { FaceCaptureService } from './FaceCaptureService';

const FACE_DIR = 'face_refs';
const XOR_KEY = 0x5A;

export class FaceReferenceStore {
  static async saveReference(context: common.UIAbilityContext, studentId: string, sourceBuffer: ArrayBuffer): Promise<string> {
    const dir = `${context.filesDir}/${FACE_DIR}`;
    FaceReferenceStore.ensureDir(dir);
    const finalPath = FaceReferenceStore.referencePath(context, studentId);
    const protectedBuffer = FaceReferenceStore.xor(sourceBuffer);
    FaceReferenceStore.writeAll(finalPath, protectedBuffer);
    return finalPath;
  }

  static async loadReference(path: string): Promise<image.PixelMap> {
    const protectedBuffer = FaceReferenceStore.readAll(path);
    const plain = FaceReferenceStore.xor(protectedBuffer);
    return await FaceCaptureService.pixelMapFromBuffer(plain);
  }

  static async clearReference(path: string): Promise<void> {
    FaceReferenceStore.safeUnlink(path);
  }

  static referencePath(context: common.UIAbilityContext, studentId: string): string {
    return `${context.filesDir}/${FACE_DIR}/${studentId}.fcimg`;
  }

  static digest(path: string): string {
    try {
      const buffer = FaceReferenceStore.readAll(path);
      let value = 0;
      const data = new Uint8Array(buffer);
      for (let index = 0; index < data.length; index += 97) {
        value = (value * 131 + data[index]) % 1000000007;
      }
      return `img-${value}-${data.length}`;
    } catch (err) {
      return 'img-unavailable';
    }
  }

  private static ensureDir(path: string): void {
    try {
      fs.mkdirSync(path);
    } catch (err) {
    }
  }

  private static readAll(path: string): ArrayBuffer {
    const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
    try {
      const stat = fs.statSync(path);
      const buffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);
      return buffer;
    } finally {
      fs.closeSync(file);
    }
  }

  private static writeAll(path: string, buffer: ArrayBuffer): void {
    const file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(file.fd, buffer);
      fs.fsyncSync(file.fd);
    } finally {
      fs.closeSync(file);
    }
  }

  private static xor(buffer: ArrayBuffer): ArrayBuffer {
    const input = new Uint8Array(buffer);
    const output = new Uint8Array(input.length);
    for (let index = 0; index < input.length; index++) {
      output[index] = input[index] ^ XOR_KEY;
    }
    return output.buffer;
  }

  private static safeUnlink(path: string): void {
    try {
      fs.unlinkSync(path);
    } catch (err) {
    }
  }
}
