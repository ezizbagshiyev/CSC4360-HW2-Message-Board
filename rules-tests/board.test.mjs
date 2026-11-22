import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { collection, deleteDoc, doc, getDoc, getDocs, runTransaction, serverTimestamp, setDoc, updateDoc } from 'firebase/firestore';

let env;
let alice, bob, visitor;
const payload = (uid = 'alice') => ({
  text: 'Campus bulletin', authorUid: uid, authorName: 'Alice Demo',
  createdAt: serverTimestamp(), editedAt: null,
});
const message = (db, id = 'notice') => doc(db, 'messages', id);

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-message-board',
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
  await env.clearFirestore();
  alice = env.authenticatedContext('alice').firestore();
  bob = env.authenticatedContext('bob').firestore();
  visitor = env.unauthenticatedContext().firestore();
  await assertSucceeds(setDoc(doc(alice, 'users', 'alice'), {
    uid: 'alice', firstName: 'Alice', lastName: 'Demo', role: 'member',
    registrationDateTime: serverTimestamp(),
  }));
  await assertSucceeds(setDoc(message(alice), payload()));
});
after(async () => { await env?.cleanup(); });

test('signed-out reads and cross-user profile reads are denied', async () => {
  await assertFails(getDocs(collection(visitor, 'messages')));
  await assertFails(getDoc(doc(bob, 'users', 'alice')));
});
test('a signed-in reader can see the post but cannot edit or delete it', async () => {
  assert.equal((await assertSucceeds(getDoc(message(bob)))).data().text, 'Campus bulletin');
  await assertFails(updateDoc(message(bob), {text: 'Changed', editedAt: serverTimestamp()}));
  await assertFails(deleteDoc(message(bob)));
});
test('forged owner and owner reassignment are denied', async () => {
  await assertFails(setDoc(message(bob, 'forgery'), payload()));
  await assertFails(updateDoc(message(alice), {authorUid: 'bob', editedAt: serverTimestamp()}));
});
test('author can create, read, edit and delete a single post', async () => {
  const ref = message(alice, 'single');
  await assertSucceeds(setDoc(ref, payload()));
  await assertSucceeds(updateDoc(ref, {text: 'Corrected bulletin', editedAt: serverTimestamp()}));
  assert.equal((await getDoc(ref)).data().text, 'Corrected bulletin');
  await assertSucceeds(deleteDoc(ref));
  assert.equal((await getDoc(ref)).exists(), false);
  assert.equal((await getDoc(message(alice))).exists(), true);
});
test('two concurrent requests with the same post ID create one document', async () => {
  const ref = message(alice, 'retried-post');
  const beforeCount = (await getDocs(collection(alice, 'messages'))).size;
  const post = () => runTransaction(alice, async (tx) => {
    if (!(await tx.get(ref)).exists()) tx.set(ref, payload());
  });
  await Promise.all([post(), post()]);
  assert.equal((await getDocs(collection(alice, 'messages'))).size, beforeCount + 1);
  assert.equal((await getDoc(ref)).data().text, 'Campus bulletin');
});
