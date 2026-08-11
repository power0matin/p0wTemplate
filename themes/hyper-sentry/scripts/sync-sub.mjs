import { copyFile, readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const indexPath = resolve(root, 'index.html');
const subPath = resolve(root, 'sub.html');

await copyFile(indexPath, subPath);
const [index, sub] = await Promise.all([readFile(indexPath), readFile(subPath)]);
if (!index.equals(sub)) {
    throw new Error('Failed to synchronize sub.html with index.html');
}
console.log('Synced sub.html from index.html');
