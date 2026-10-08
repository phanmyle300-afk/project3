import { initializeApp } from "firebase/app";
import { getFirestore, collection, addDoc, getDocs, deleteDoc, doc, query, orderBy } from "firebase/firestore";
import { getStorage, ref, uploadBytes, getDownloadURL } from "firebase/storage";

// Your web app's Firebase configuration (Project: hoadonproject3)
export const firebaseConfig = {
  apiKey: "AIzaSyBtr0Wr8yMNpYoijyDWB6Uvm_Jf_KjcW4g",
  authDomain: "my-receipt-tracker-76618.firebaseapp.com",
  projectId: "my-receipt-tracker-76618",
  storageBucket: "my-receipt-tracker-76618.firebasestorage.app",
  messagingSenderId: "1055631814030",
  appId: "1:1055631814030:web:8c258717ba2bb533fcc8df"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const db = getFirestore(app);
const storage = getStorage(app);

export { app, db, storage };

// --- Firebase Firestore Helper Functions ---

export async function saveTransactionToFirebase(transaction) {
  try {
    const docRef = await addDoc(collection(db, "receipt_transactions"), {
      ...transaction,
      createdAt: new Date().toISOString()
    });
    console.log("Document written to Firebase Firestore with ID: ", docRef.id);
    return docRef.id;
  } catch (e) {
    console.error("Error adding document to Firebase: ", e);
    throw e;
  }
}

export async function getTransactionsFromFirebase() {
  try {
    const q = query(collection(db, "receipt_transactions"), orderBy("date", "desc"));
    const querySnapshot = await getDocs(q);
    const txs = [];
    querySnapshot.forEach((docSnap) => {
      txs.push({
        id: docSnap.id,
        ...docSnap.data()
      });
    });
    return txs;
  } catch (e) {
    console.error("Error fetching transactions from Firebase: ", e);
    return [];
  }
}

export async function deleteTransactionFromFirebase(docId) {
  try {
    await deleteDoc(doc(db, "receipt_transactions", docId));
    console.log("Deleted document from Firebase: ", docId);
  } catch (e) {
    console.error("Error deleting document from Firebase: ", e);
  }
}

export async function uploadReceiptImageToFirebase(file) {
  try {
    const storageRef = ref(storage, `receipts/${Date.now()}_${file.name}`);
    const snapshot = await uploadBytes(storageRef, file);
    const downloadUrl = await getDownloadURL(snapshot.ref);
    return downloadUrl;
  } catch (e) {
    console.error("Error uploading image to Firebase Storage: ", e);
    return null;
  }
}
