import { initializeApp, FirebaseApp } from 'firebase/app';
import { getFirestore, Firestore } from 'firebase/firestore';
import { getAuth, Auth } from 'firebase/auth';
import { environment } from '../../environments/environment';

/**
 * Application Firebase initialisée.
 */
export const app: FirebaseApp = initializeApp(environment.firebaseConfig);

/**
 * Référence au service Firestore.
 */
export const db: Firestore = getFirestore(app);

/**
 * Référence au service Auth (gestion de l'authentification).
 */
export const auth: Auth = getAuth(app);
