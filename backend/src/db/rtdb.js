const admin = require('firebase-admin');
const { initializeFirebase } = require('../config/firebase');

function getDatabase() {
  initializeFirebase();
  return admin.database();
}

function ref(path) {
  return getDatabase().ref(path);
}

function nowIso() {
  return new Date().toISOString();
}

function ensureStringId(id, fieldName = 'id') {
  if (typeof id !== 'string' || !id.trim()) {
    throw new Error(`${fieldName} must be a non-empty string.`);
  }
  return id.trim();
}

function normalizeEmail(email) {
  return String(email ?? '').trim().toLowerCase();
}

function pairKey(a, b) {
  const idA = ensureStringId(a, 'userAId');
  const idB = ensureStringId(b, 'userBId');
  return idA < idB ? `${idA}_${idB}` : `${idB}_${idA}`;
}

async function getValue(path) {
  const snap = await ref(path).get();
  return snap.exists() ? snap.val() : null;
}

async function setValue(path, value) {
  await ref(path).set(value);
}

async function updateValue(path, partial) {
  await ref(path).update(partial);
}

async function removeValue(path) {
  await ref(path).remove();
}

async function pushChild(path, value) {
  const child = ref(path).push();
  await child.set(value);
  return { key: child.key, ref: child };
}

module.exports = {
  getDatabase,
  ref,
  nowIso,
  ensureStringId,
  normalizeEmail,
  pairKey,
  getValue,
  setValue,
  updateValue,
  removeValue,
  pushChild,
};

