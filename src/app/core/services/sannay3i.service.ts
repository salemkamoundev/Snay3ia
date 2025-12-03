import { Injectable } from '@angular/core';
import { collection, addDoc, Firestore } from 'firebase/firestore';
import { supabase, STORAGE_BUCKET_BREAKDOWNS } from '../supabase.client';
import { db, auth } from '../firebase.config';

interface Job {
  description: string;
  imageUrl: string;
  status: 'pending' | 'analyzing' | 'assigned' | 'completed';
  createdAt: Date;
  userId: string;
  userEmail?: string;
}

@Injectable({
  providedIn: 'root'
})
export class Sannay3iService {
  private firestore: Firestore = db;
  private jobsCollection = collection(this.firestore, 'jobs');

  // Fonction utilitaire pour générer un ID unique sans librairie externe
  private generateId(): string {
    return Date.now().toString(36) + Math.random().toString(36).substr(2);
  }

  async createJob(description: string, file: File): Promise<string> {
    console.log('[Service] Début createJob...');

    // 1. Vérification Auth
    const user = auth.currentUser;
    if (!user) {
      console.error('[Service] Erreur: Utilisateur non connecté');
      throw new Error("Vous devez être connecté pour soumettre une demande.");
    }

    try {
      // 2. Préparation du fichier
      const fileExt = file.name.split('.').pop();
      const fileName = `${user.uid}/${this.generateId()}.${fileExt}`;
      
      console.log(`[Service] Upload vers Supabase : ${fileName}`);

      // 3. Upload Supabase
      const { data, error: uploadError } = await supabase.storage
        .from(STORAGE_BUCKET_BREAKDOWNS)
        .upload(fileName, file, {
          cacheControl: '3600',
          upsert: false
        });

      if (uploadError) {
        console.error('[Service] Erreur Upload Supabase:', uploadError);
        throw new Error(`Erreur Upload: ${uploadError.message}`);
      }

      // 4. Récupération URL
      const { data: urlData } = supabase.storage
        .from(STORAGE_BUCKET_BREAKDOWNS)
        .getPublicUrl(fileName);

      if (!urlData.publicUrl) {
        throw new Error("Impossible de récupérer l'URL publique.");
      }
      console.log('[Service] URL obtenue:', urlData.publicUrl);

      // 5. Sauvegarde Firestore
      const newJob: Job = {
        description: description,
        imageUrl: urlData.publicUrl,
        status: 'analyzing', // Déclenche la Cloud Function si elle est déployée
        createdAt: new Date(),
        userId: user.uid,
        userEmail: user.email || 'Anonyme'
      };

      console.log('[Service] Création document Firestore...');
      const docRef = await addDoc(this.jobsCollection, newJob);
      console.log('[Service] Succès ! ID du Job:', docRef.id);

      return docRef.id;

    } catch (error: any) {
      console.error('[Service] EXCEPTION:', error);
      throw error;
    }
  }
}
